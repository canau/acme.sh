#!/usr/bin/bash

#Here is a script to deploy cert to haraka server.
# (edited from exim4.sh - bound to certs in /opt/Haraka/config/tls directory)

#returns 0 means success, otherwise error.

DEPLOY_HARAKA_CONF="/opt/Haraka/config/tls.ini"
DEPLOY_HARAKA_RELOAD="systemctl restart haraka"
DEPLOY_HARAKA_SSL_PATH="/opt/Haraka/config/tls"

########  Public functions #####################

#domain keyfile certfile cafile fullchain
haraka_deploy() {
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

  _ssl_path=$DEPLOY_HARAKA_SSL_PATH
  if ! mkdir -p "$_ssl_path"; then
    _err "Can not create folder:$_ssl_path"
    return 1
  fi

  _info "Copying key and cert"
  _real_key="$_ssl_path/${_cdomain}.privkey.pem"
  if ! cat "$_ckey" >"$_real_key"; then
    _err "Error: write key file to: $_real_key"
    return 1
  fi
  _real_fullchain="$_ssl_path/${_cdomain}.pubcert.pem"
  if ! cat "$_cfullchain" >"$_real_fullchain"; then
    _err "Error: write key file to: $_real_fullchain"
    return 1
  fi

  DEFAULT_HARAKA_RELOAD="service haraka restart"
  _reload="${DEPLOY_HARAKA_RELOAD:-$DEFAULT_HARAKA_RELOAD}"

  if [ -z "$IS_RENEW" ]; then
    DEFAULT_HARAKA_CONF="/etc/exim/exim.conf"
    if [ ! -f "$DEFAULT_HARAKA_CONF" ]; then
      DEFAULT_HARAKA_CONF="/etc/haraka/haraka.conf.template"
    fi
    _haraka_conf="${DEPLOY_HARAKA_CONF:-$DEFAULT_HARAKA_CONF}"
    _debug _haraka_conf "$_haraka_conf"
    if [ ! -f "$_haraka_conf" ]; then
      if [ -z "$DEPLOY_HARAKA_CONF" ]; then
        _err "haraka conf is not found, please define DEPLOY_HARAKA_CONF"
        return 1
      else
        _err "It seems that the specified haraka conf is not valid, please check."
        return 1
      fi
    fi
    if [ ! -w "$_haraka_conf" ]; then
      _err "The file $_haraka_conf is not writable, please change the permission."
      return 1
    fi
    _backup_conf="$DOMAIN_BACKUP_PATH/haraka.conf.bak"
    _info "Backup $_haraka_conf to $_backup_conf"
    cp "$_haraka_conf" "$_backup_conf"

    _info "Modify haraka conf: $_haraka_conf"
    if _setopt "$_haraka_conf" "cert" "=" "tls/${_cdomain}.pubcert.pem" \
      && _setopt "$_haraka_conf" "key" "=" "tls/${_cdomain}.privkey.pem"; then
      _info "Set config success!"
    else
      _err "Config haraka server error, please report bug to us."
      _info "Restoring haraka conf"
      if cat "$_backup_conf" >"$_haraka_conf"; then
        _info "Restore conf success"
        eval "$_reload"
      else
        _err "Oops, error restore haraka conf, please report bug to us."
      fi
      return 1
    fi
  fi

  _info "Run reload: $_reload"
  if eval "$_reload"; then
    _info "Reload success!"
    if [ "$DEPLOY_HARAKA_CONF" ]; then
      _savedomainconf DEPLOY_HARAKA_CONF "$DEPLOY_HARAKA_CONF"
    else
      _cleardomainconf DEPLOY_HARAKA_CONF
    fi
    if [ "$DEPLOY_HARAKA_RELOAD" ]; then
      _savedomainconf DEPLOY_HARAKA_RELOAD "$DEPLOY_HARAKA_RELOAD"
    else
      _cleardomainconf DEPLOY_HARAKA_RELOAD
    fi
    return 0
  else
    _err "Reload error, restoring"
    if cat "$_backup_conf" >"$_haraka_conf"; then
      _info "Restore conf success"
      eval "$_reload"
    else
      _err "Oops, error restore haraka conf, please report bug to us."
    fi
    return 1
  fi
  return 0

}
