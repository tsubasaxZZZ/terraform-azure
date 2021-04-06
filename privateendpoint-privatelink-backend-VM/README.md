## RST パケットのキャプチャ

```
tcpdump -n -i eth0 '(tcp[tcpflags] & tcp-rst)' != 0
```

## TCPのステート

```
ss -anps
```

## JMeter ダッシュボードの Graphの粒度変更


```
# vi /opt/apache-jmeter-5.4.1/bin/user.properties
jmeter.reportgenerator.overall_granularity=10000
```

## テストスクリプト

```
#!/bin/sh -xe
DATE=$(date +%Y%m%d%H%M%S)
jmeter -n -t PrivateLinkTest.jmx -l PrivateLinkTest_${DATE}.jtl
jmeter -g PrivateLinkTest_${DATE}.jtl -o dashboard_${DATE}
```