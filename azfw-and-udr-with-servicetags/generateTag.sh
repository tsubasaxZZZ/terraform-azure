#!/bin/sh
set -eux

\rm var.txt

az network list-service-tags --location japaneast -o json | jq '.values[].name' | egrep -v '\.' > taglist
az network list-service-tags --location japaneast -o json | jq '.values[].name' | egrep -i '\.japaneast' >> taglist

#tagcount=`cat taglist | wc -l`
i=0
echo "udr_service_tags=[" > var.txt
for tag in `cat taglist`
do
    echo $tag >> .temp.tag
    i=$((i+1))
    if [ $(($i % 25)) -eq 0 ]; then
        t=$(cat .temp.tag | tr '\r\n' ',' | sed 's/,$//')
        printf "[%s]," $t >> var.txt
        >.temp.tag
    fi
done

t=$(cat .temp.tag | tr '\r\n' ',' | sed 's/,$//')
printf "[%s]" $t >> var.txt

echo "]" >> var.txt

\rm taglist
\rm .temp.tag