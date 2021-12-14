#!/usr/bin/env bash
set -e -o pipefail

# req <method> <path> <curl arg ...>
req() {
	local out
	out="$(curl -s -X "$1" "https://api.cloudflare.com/client/v4/$2" \
		-H "Authorization: Bearer $CF_API_KEY" "${@:3}")"
	if [[ "$(printf '%s' "$out" | jq -r '.success')" != true ]]; then
		printf 'error from cloudflare api:\n%s\n' "$out" 1>&2
		exit 1
	fi
	printf '%s' "$out"
}

# zid <domain>
zid() { req GET "zones?name=$1" | jq -r '.result[0].id'; }

# rid <zone id> <domain> <acme token>
rid() { req GET "zones/$1/dns_records?type=TXT&name=$2&content=$3" | jq -r '.result[0].id'; }

case "$1" in
deploy_challenge)
	DOMAIN="$2" TOKEN="$4"
	ZID="$(zid "$DOMAIN")"
	data="{\"type\":\"TXT\",\"name\":\"_acme-challenge.$DOMAIN\",\"content\":\"$TOKEN\",\"ttl\":60}"
	req POST "zones/$ZID/dns_records" --data "$data" >/dev/null
	printf 'waiting for %d seconds\n' 10 1>&2
	sleep 10
	;;
clean_challenge)
	DOMAIN="$2" TOKEN="$4"
	ZID="$(zid "$DOMAIN")"
	RID="$(rid "$ZID" "_acme-challenge.$DOMAIN" "$TOKEN_VALUE")"
	req DELETE "zones/$ZID/dns_records/$RID" >/dev/null
	;;
invalid_challenge)
	DOMAIN="$2" RESPONSE="$3"
	printf 'Validation of %s failed. Response:\n%s\n' "$DOMAIN" "$RESPONSE" 1>&2
	;;
# deploy_cert)
# 	DOMAIN="$2" KEYFILE="$3" CERTFILE="$4" FULLCHAINFILE="$5" CHAINFILE="$6" TIMESTAMP="$7"
# 	for f in "$KEYFILE" "$CERTFILE" "$FULLCHAINFILE" "$CHAINFILE"; do
# 		chmod 640 "$f"
# 		chown acme:tlscert "$f"
# 	done
# 	systemctl restart nginx.service
# 	;;
esac
