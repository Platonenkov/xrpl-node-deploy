# Как использовать

Залей конфиг на свой домен, например:

URL: https://xrpl.node.staticbit.io/configs/rippled-light.cfg

Внутри — один из наших конфигов (rippled-light.cfg / rippled-api.cfg и т.д.)

На чистом сервере (Debian/Ubuntu):

```
wget https://xrpl.node.staticbit.io/scripts/setup-mainnet.sh -O setup-mainnet.sh
chmod +x setup-mainnet.sh
sudo ./setup-mainnet.sh
```

(URL, разумеется, можешь выбрать любой — главное, чтобы совпадал с тем, что в CONFIG_URL в скрипте.)

Проверка: `rippled server_info`


В ответе должно быть `"server_state": "full"` спустя время синхронизации.