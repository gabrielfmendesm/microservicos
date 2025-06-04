# Cache com Redis no Product Service

Implementei o cache usando Redis no microserviço Product para melhorar o desempenho e reduzir chamadas ao banco de dados. A seguir, descrevo as principais alterações que fiz.

---

## Configuração no Minikube

Para rodar o Redis junto com os serviços, adicionei o arquivo `redis.yaml` no diretório `k8s/`. O Deployment e Service ficaram assim:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  labels:
    app: redis
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
        - name: redis
          image: redis:6.2-alpine
          ports:
            - containerPort: 6379
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  labels:
    app: redis
spec:
  type: ClusterIP
  selector:
    app: redis
  ports:
    - port: 6379
      targetPort: 6379
```

Depois de aplicar esse `redis.yaml` com `kubectl apply -f k8s/redis.yaml`, o Redis ficou disponível no cluster, e pude confirmar com:

```bash
kubectl get pods
```

Que mostrou algo como:

```
NAME                        READY   STATUS    RESTARTS   AGE
...
product-5cf9d54c89-5fqpv     1/1     Running   0          17m
redis-66c4bb97fd-6vqqc       1/1     Running   0          17m
...
```

---

## Alterações no `application.yaml`

No `src/main/resources/application.yaml` do Product, a conexão com o Redis foi configurada assim:

```yaml
spring:
  data:
    redis:
      host: redis   # nome do Service no Kubernetes
      port: 6379
```

Com isso, o Spring Boot consegue encontrar o Redis pelo serviço de DNS interno do cluster.

---

## Dependências adicionais

Atualizei o `pom.xml` para incluir:

```xml
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-data-redis</artifactId>
</dependency>
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-cache</artifactId>
</dependency>
```

Essas dependências ativam o suporte a cache e a integração com Redis.

---

## Modificações no código

### `ProductApplication.java`

Habilitei o cache adicionando `@EnableCaching`:

```java
package store.product;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cache.annotation.EnableCaching;

@SpringBootApplication
@EnableCaching
public class ProductApplication {
  public static void main(String[] args) {
    SpringApplication.run(ProductApplication.class, args);
  }
}
```

### `ProductService.java`

Implementei anotações de cache em métodos de leitura e limpeza de cache em métodos de escrita:

```java
package store.product;

import java.util.List;
import java.util.stream.StreamSupport;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
public class ProductService {

    @Autowired
    private ProductRepository productRepository;

    @CacheEvict(value = "products", allEntries = true)
    public Product create(Product product) {
        return productRepository.save(new ProductModel(product)).to();
    }

    @Cacheable(value = "products", key = "#id")
    public Product findById(String id) {
        return productRepository.findById(id)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Product not found"))
            .to();
    }

    @Cacheable(value = "products", key = "'all'")
    public List<Product> findAll() {
        return StreamSupport.stream(productRepository.findAll().spliterator(), false)
            .map(ProductModel::to)
            .toList();
    }

    @CacheEvict(value = "products", allEntries = true)
    public void deleteById(String id) {
        if (!productRepository.existsById(id)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Product not found");
        }
        productRepository.deleteById(id);
    }
}
```

### `Product.java`

Para permitir a serialização de objetos no cache, tornei a entidade serializável:

```java
package store.product;

import java.io.Serializable;

import lombok.Builder;
import lombok.Data;
import lombok.experimental.Accessors;

@Builder
@Data
@Accessors(fluent = true)
public class Product implements Serializable {
    private static final long serialVersionUID = 1L;

    private String id;
    private String name;
    private Double price;
    private String unit;
}
```

---

## Resultado

Após essas mudanças, o cache começou a “pegar” corretamente. Ao fazer requisições ao endpoint `GET /product/{id}` logo na primeira chamada o Redis ainda não tinha o valor, e nas chamadas seguintes o Redis respondeu, conforme monitorei com:

```bash
kubectl exec -it deploy/redis -- redis-cli MONITOR
```

Exemplos de comandos observados:

```
GET products::all
SET products::all [bytes serializados]
GET products::a045edae-794f-4e53-a2ea-562b68ea01c9
SET products::a045edae-794f-4e53-a2ea-562b68ea01c9 [bytes serializados]
```

E o `kubectl get pods` mostra o Redis rodando ao lado dos demais serviços:

```
NAME                         READY   STATUS    RESTARTS   AGE
account-68c6c5b66f-vtv82     1/1     Running   0          24m
auth-6dd6bcd966-vlmls        1/1     Running   0          24m
gateway-7ffd75cf9d-hjqkf     1/1     Running   0          24m
order-8578847bb6-qj6cd       1/1     Running   0          24m
product-5cf9d54c89-xfz94     1/1     Running   0          24m
postgres-86d6bb...           1/1     Running   0          20m
redis-66c4bb97fd-jrv9w       1/1     Running   0          24m
```