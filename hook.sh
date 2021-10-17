#!/usr/bin/env bash
# TODO: prettier output instead of raw json i guess
set -e -o pipefail -x

# req <method> <path> <curl arg ...>
req() {
	curl -s -X "$1" "https://api.cloudflare.com/client/v4/$2" \
		-H "Authorization: Bearer $CF_API_KEY" "${@:3}"
}

# zid <domain>
zid() { req GET "zones?name=$1" | jq -r '.result[0].id'; }

# rid <zone id> <domain> <acme token>
rid() { req GET "zones/$1/dns_records?type=TXT&name=$2&content=$3" | jq -r '.result[0].id'; }

case "$1" in
deploy_challenge)
	DOMAIN="$2" TOKEN_FILENAME="$3" TOKEN_VALUE="$4"
	ZID="$(zid "$DOMAIN")"
	req POST "zones/$ZID/dns_records" --data \
		"{\"type\":\"TXT\",\"name\":\"_acme-challenge.$DOMAIN\",\"content\":\"$TOKEN_VALUE\",\"ttl\":60}"
	printf 'waiting for %d seconds\n' 10 1>&2
	sleep 10
	;;
clean_challenge)
	DOMAIN="$2" TOKEN_FILENAME="$3" TOKEN_VALUE="$4"
	ZID="$(zid "$DOMAIN")"
	RID="$(rid "$ZID" "_acme-challenge.$DOMAIN" "$TOKEN_VALUE")"
	req DELETE "zones/$ZID/dns_records/$RID"
	;;
invalid_challenge)
	DOMAIN="$2" RESPONSE="$3"
	printf 'Validation of %s failed. Response:\n%s\n' "$DOMAIN" "$RESPONSE" 1>&2
	;;
# deploy_cert)
# 	DOMAIN="$2" KEYFILE="$3" CERTFILE="$4" FULLCHAINFILE="$5" CHAINFILE="$6" TIMESTAMP="$7"
# 	for f in "$KEYFILE" "$CERTFILE" "$FULLCHAINFILE" "$CHAINFILE"; do
# 		chown acme:tlscert "$f"
# 		chmod 640 "$f"
# 	done
# 	systemctl restart nginx.service
# 	;;
esac
