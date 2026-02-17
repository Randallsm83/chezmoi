# ███████╗███████╗██╗  ██╗
# ╚══███╔╝██╔════╝██║  ██║
#   ███╔╝ ███████╗███████║
#  ███╔╝  ╚════██║██╔══██║
# ███████╗███████║██║  ██║
# ╚══════╝╚══════╝╚═╝  ╚═╝
# Z Shell - powerful command interpreter.
#

#!/usr/bin/env zsh

# Only load on NDN servers (where /dh/bin exists)
[[ ! -d /dh/bin ]] && return 0

# NDN Aliases
alias dbc='sudo /dh/bin/dbc'
# alias dbc='/usr/bin/perl /dh/bin/dbc'
alias dhdb='sudo /dh/bin/dh-db'
alias dhd='sudo /dh/bin/dh-domain'
alias dhc='sudo /dh/bin/dhcat'
alias dhip='sudo /dh/bin/dh-ip'
alias dhm='sudo /dh/bin/dh-machine'
alias dhq='sudo /dh/bin/dhq'
alias dhd='sudo /dh/bin/dh-domain'
alias dh-db='sudo /dh/bin/dh-db'
alias dhcat='sudo /dh/bin/dhcat'
alias dhtail='sudo /dh/bin/dhtail'
alias dh-domain='sudo /dh/bin/dh-domain'
alias dh-ip='sudo /dh/bin/dh-ip'
alias dh-machine='sudo /dh/bin/dh-machine'
alias dhqs="dhqsearch --f='squid,home,service,command,executed_by_home,scheduled,finished,result' -X 'exec_delay,runtime'"
alias dhqsearch='sudo /dh/bin/dhqsearch'
alias dhsh.pl='sudo /dh/bin/dhsh.pl'
alias dh-cluster='sudo /dh/bin/dh-cluster'
alias dh-watcher.pl='sudo /dh/bin/dh-watcher.pl'
alias enableactt='sc yakko reenabler reenable'
alias firewall.pl='sudo /dh/bin/firewall.pl'
alias loady.pl='sudo /dh/bin/loady.pl'
alias location-fix.pl='sudo /dh/bin/location-fix.pl'
alias mail_log_jumper='sudo /dh/bin/mail_log_jumper'
alias mlj='sudo /dh/bin/mail_log_jumper -t'
alias mljt='sudo /dh/bin/mail_log_jumper -t'
alias move.pl='sudo /dh/bin/move.pl'
alias movedata.pl='sudo /dh/bin/movedata.pl'
alias movemysql.pl='sudo /dh/bin/movemysql.pl'
alias movemysql_service.pl='sudo /dh/bin/movemysql_service.pl'
alias ndn-password='sudo /dh/bin/ndn-password'
alias ns='sudo /dh/bin/nsconfig'
alias nsconfig='sudo /dh/bin/nsconfig'
alias oc-up='sudo /dh/bin/servicectl yakko installer upgradenew'
alias pass='sudo /dh/bin/epasswd.pl -d'
alias reboot='/usr/local/ndn/dh/bin/reboot.pl'
alias rebooty.pl='sudo /dh/bin/rebooty.pl'
alias rsh='sudo rsh'
alias rssh='ssh -l root'
alias sc='sudo /dh/bin/servicectl'
alias sctl='sudo /dh/bin/servicectl'
alias servicectl='sudo /dh/bin/servicectl'
alias sp='sudo /dh/bin/siteperformance -vv'
alias test-mail='sudo /dh/bin/test-mail'
alias getpass='sudo /dh/bin/test_password'
alias getusid='sudo /dh/bin/dh-email'
alias what-mounts='sudo /dh/bin/what-mounts'
alias wildcard-dns.pl='sudo /dh/bin/wildcard-dns.pl'

# Dev Aliases
DEV_ENV="/usr/bin/sudo /usr/bin/env DH_TEMPLATE_PREFIX=${HOME}/projects/ndn PERL5LIB=${HOME}/projects/ndn/perl "
alias mysc="${DEV_ENV} ${HOME}/projects/ndn/dh/bin/servicectl"
alias scdb="${DEV_ENV} perl -d ${HOME}/projects/ndn/dh/bin/servicectl"
alias domy="${DEV_ENV}"
alias ndntest="${DEV_ENV} prove -v"
alias vix="vi ${HOME}/bin/scratchpad/x.pl"
alias x="sudo perl ${HOME}/bin/scratchpad/x.pl"
alias dhperl="${DEV_ENV} /usr/bin/perl -I${HOME}/projects/ndn/perl"

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------
