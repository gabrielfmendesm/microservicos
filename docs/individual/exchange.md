A Exchange API foi desenvolvida com **FastAPI em Python** e tem como objetivo permitir a conversão entre moedas por meio de um endpoint REST autenticado. As cotações são obtidas em tempo real utilizando a [ExchangeRate-API](https://www.exchangerate-api.com), com valores atualizados diretamente da web.

---

#### Endpoint principal

`GET /exchange/{from}/{to}`

---

#### Exemplo de resposta

```json
{
  "sell": 0.82,
  "buy": 0.80,
  "date": "2021-09-01 14:23:42",
  "id-account": "0195ae95-5be7-7dd3-b35d-7a7d87c404fb"
}
```

---

#### Autenticação

O acesso a este endpoint exige autenticação com token JWT, que é validado pelo **API Gateway** antes de encaminhar a requisição ao microserviço Exchange.

---

#### Diagrama de Integração com Gateway

![Diagrama de Integração da Exchange API](../img/diagrama-exchange.png)
