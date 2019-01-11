#!/usr/bin/env sh

# Script to create certificate to qiniu.com 
#
# This deployment required following variables
# export QINIU_AK="QINIUACCESSKEY"
# export QINIU_SK="QINIUSECRETKEY"

QINIU_API_BASE="https://api.qiniu.com"

qiniu_deploy() {
  _cdomain="$1"
  _ckey="$2"
  _ccert="$3"
  _cca="$4"
  _cfullchain="$5"

  _debug _cdomain "$_cdomain"
  _debug _ckey "$_ckey"
  _debug _ccert "$_ccert"
  _debug _cca "$_cca"
  _debug _cfullchain "$_cfullchain"

  if [ -z "$QINIU_AK" ]; then
    if [ -z "$Le_Deploy_Qiniu_AK" ]; then
      _err "QINIU_AK is not defined."
      return 1
    fi
  else
    Le_Deploy_Qiniu_AK="$QINIU_AK"
    _savedomainconf Le_Deploy_Qiniu_AK "$Le_Deploy_Qiniu_AK"
  fi

  if [ -z "$QINIU_SK" ]; then
    if [ -z "$Le_Deploy_Qiniu_SK" ]; then
      _err "QINIU_SK is not defined."
      return 1
    fi
  else
    Le_Deploy_Qiniu_SK="$QINIU_SK"
    _savedomainconf Le_Deploy_Qiniu_SK "$Le_Deploy_Qiniu_SK"
  fi

  string_fullchain=$(awk '{printf "%s\\n", $0}' "$_cfullchain")
  string_key=$(awk '{printf "%s\\n", $0}' "$_ckey")

  sslcerl_body="{\"name\":\"$_cdomain\",\"common_name\":\"$_cdomain\",\"ca\":\""$string_fullchain"\",\"pri\":\"$string_key\"}"

  create_ssl_url="$QINIU_API_BASE/sslcert"

  sslcert_access_token="$(_make_sslcreate_access_token "/sslcert\\n")"
  _debug sslcert_access_token "$sslcert_access_token"
  export _H1="Authorization: QBox $sslcert_access_token"

  sslcert_response=$(_post "$sslcerl_body" "$create_ssl_url" 0 "POST" "application/json" | _dbase64 "multiline")

  success_response="certID"
  if test "${sslcert_response#*$success_response}" == "$sslcert_response"; then
    _err "Error in creating certificate:"
    _err "$sslcert_response"
    return 1
  fi

  _debug sslcert_response "$sslcert_response"
  _info "Certificate successfully uploaded, updating domain $_cdomain"

  _certId=$(printf "%s" $sslcert_response | sed -e "s/^.*certID\":\"//" -e "s/\"\}$//")
  _debug certId "$_certId"

  update_path="/domain/$_cdomain/httpsconf"
  update_url="$QINIU_API_BASE$update_path"
  update_body="{\"certid\":\""$_certId"\",\"forceHttps\":true}"

  update_access_token="$(_make_sslcreate_access_token "$update_path\\n")"
  _debug update_access_token "$update_access_token"
  export _H1="Authorization: QBox $update_access_token"
  update_response=$(_post "$update_body" "$update_url" 0 "PUT" "application/json" | _dbase64 "multiline")

  err_response="error"
  if test "${update_response#*$err_response}" != "$update_response"; then
    _err "Error in updating domain:"
    _err "$update_response"
    return 1
  fi

  _debug update_response "$update_response"
  _info "Certificate successfully deployed"

  return 0
}

_make_sslcreate_access_token() {
  _data="$1"
  _token="$(printf "$_data" | openssl sha1 -hmac $Le_Deploy_Qiniu_SK -binary | openssl base64 -e)"
  echo "$Le_Deploy_Qiniu_AK:$_token"
}
