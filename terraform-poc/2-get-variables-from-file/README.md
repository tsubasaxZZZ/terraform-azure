# README

## Get vm information

```
az vm list-skus --all -l japaneast --query "[?capabilities[?name=='AcceleratedNetworkingEnabled' && value=='True']].name" -o json > AcceleratedNetworkingEnabledVM.json
```