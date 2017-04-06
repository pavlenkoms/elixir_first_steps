# Kvstore
Задача. key-value хранилище
Управление через веб (GET POST PUT/PATCH DELETE)

## Как класть и брать?
### Класть
POST запрос на ресурс, uri которого следующего вида /KEY/VALUE/[TTL]
  * TTL - число от 0 до овермного в миллисекундах. Ежели ноль или отсутствует, то храним пока не удалят

### Изменять
см пункт класть, но методом PUT/PATCH

### Брать
GET запрос на ресурс, uri которого /KEY. Значение искать где то в теле ответа

## Запускать
Запуск осуществляется стандартно: iex -S mix

## Тестировать
mix test
