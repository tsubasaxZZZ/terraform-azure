# README

## 出来るもの

Zabbix サーバーとクライアントの一式が出来上がります。

## Packer

- ファイル
    - zabbix-server.pkr.hcl

Packer を使って Azure 上にイメージを作成します。Zabbix サーバーがインストールされたイメージ、監視対象として Zabbix エージェントがインストールされたイメージが作成されます。

リソース グループやリージョンは適宜変更します。

実行方法:
```
packer build zabbix.pkr.hcl
```

## Ansible

- ファイル
    - playbook ディレクトリ配下

Ansible の実行例:
```
ansible-playbook playbook/install-zabbix-server.yaml -i playbook/inventory/production
```

## Terraform

- ファイル
    - main.tf
    - terraform.tfvars
    - modules

Azure 上への仮想マシンの展開と起動後の Zabbix エージェントの設定ファイルの変更を行います。Packer によって展開されたイメージを基に作成します。

terraform.tfvars の設定例:
```
ssh_key_path = "~/.ssh/id_rsa.pub"
custom_image_resource_group_name = "rg-iacpoc"
zabbix_server_custom_image_name = "UbuntuServer-zabbix-server"
zabbix_client_custom_image_name = "UbuntuServer-zabbix-client"
location = "japaneast"
```


## Zabbix の設定

自動登録アクションを設定すると、エージェントが起動したタイミングで自動的に監視が始まります。