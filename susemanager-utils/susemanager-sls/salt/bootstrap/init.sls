# Make sure no SUSE Manager server aliasing left over from ssh-push via tunnel
mgr_server_localhost_alias_absent:
  host.absent:
    - ip:
      - 127.0.0.1
    - names:
      - {{ salt['pillar.get']('mgr_server') }}

# disable all susemanager:* repos
{% set repos_disabled = {'match_str': 'susemanager:', 'matching': true} %}
{%- include 'channels/disablelocalrepos.sls' %}

{% set os_base = 'sle' %}
# CentOS6 oscodename is bogus
{%- if "centos" in grains['os']|lower %}
{% set os_base = 'centos' %}
{%- elif "redhat" in grains['os']|lower %}
{% set os_base = 'res' %}
{%- elif "alibaba" in grains['os']|lower %}
{% set os_base = 'alibaba' %}
{%- elif "opensuse" in grains['oscodename']|lower %}
{% set os_base = 'opensuse' %}
{%- endif %}

{%- if grains['os_family'] == 'Suse' %}
{%- if "." in grains['osrelease'] %}
{% set bootstrap_repo_url = 'https://' ~ salt['pillar.get']('mgr_server') ~ '/pub/repositories/' ~ os_base ~ '/' ~ grains['osrelease'].replace('.', '/') ~ '/bootstrap/' %}
{%- else %}
{% set bootstrap_repo_url = 'https://' ~ salt['pillar.get']('mgr_server') ~ '/pub/repositories/' ~ os_base ~ '/' ~ grains['osrelease'] ~ '/0/bootstrap/' %}
{%- endif %}

{%- elif grains['os_family'] == 'RedHat' %}
{%- if salt['file.file_exists']('/etc/oracle-release') %}
{% set bootstrap_repo_url = 'https://' ~ salt['pillar.get']('mgr_server') ~ '/pub/repositories/oracle/' ~ grains['osmajorrelease'] ~ '/bootstrap/' %}

{%- elif salt['file.file_exists']('/etc/alinux-release') %}
{% set bootstrap_repo_url = 'https://' ~ salt['pillar.get']('mgr_server') ~ '/pub/repositories/alibaba/' ~ grains['osmajorrelease'] ~ '/bootstrap/' %}

{%- elif salt['file.file_exists']('/usr/share/doc/sles_es-release') %}
{% set bootstrap_repo_url = 'https://' ~ salt['pillar.get']('mgr_server') ~ '/pub/repositories/res/' ~ grains['osmajorrelease'] ~ '/bootstrap/' %}

{%- elif salt['file.file_exists']('/etc/system-release') %}
{% set bootstrap_repo_url = 'https://' ~ salt['pillar.get']('mgr_server') ~ '/pub/repositories/amzn/' ~ grains['osmajorrelease'] ~ '/bootstrap/' %}

{%- elif salt['file.file_exists']('/etc/almalinux-release') %}
{% set bootstrap_repo_url = 'https://' ~ salt['pillar.get']('mgr_server') ~ '/pub/repositories/almalinux/' ~ grains['osmajorrelease'] ~ '/bootstrap/' %}

{%- elif salt['file.file_exists']('/etc/centos-release') %}
{# We try CentOS bootstrap repository first, if not available then fallback to RES #}
{% set bootstrap_repo_url = 'https://' ~ salt['pillar.get']('mgr_server') ~ '/pub/repositories/centos/' ~ grains['osmajorrelease'] ~ '/bootstrap/' %}
{% set bootstrap_repo_request = salt['http.query'](bootstrap_repo_url + 'repodata/repomd.xml', status=True, verify_ssl=False) %}
{%- if bootstrap_repo_request['status'] == 901 %}
{{ raise(bootstrap_repo_request['error']) }}
{%- elif not (0 < bootstrap_repo_request['status'] < 300) %}
{% set bootstrap_repo_url = 'https://' ~ salt['pillar.get']('mgr_server') ~ '/pub/repositories/res/' ~ grains['osmajorrelease'] ~ '/bootstrap/' %}
{%- endif %}

{%- elif salt['file.file_exists']('/etc/redhat-release') %}
{% set bootstrap_repo_url = 'https://' ~ salt['pillar.get']('mgr_server') ~ '/pub/repositories/res/' ~ grains['osmajorrelease'] ~ '/bootstrap/' %}

{%- else %}
{% set bootstrap_repo_url = 'https://' ~ salt['pillar.get']('mgr_server') ~ '/pub/repositories/' ~ os_base ~ '/' ~ grains['osmajorrelease'] ~ '/bootstrap/' %}
{%- endif %}

{%- elif grains['os_family'] == 'Debian' %}
{%- set osrelease = grains['osrelease'].split('.') %}
{%- if grains['os'] == 'Ubuntu' %}
{% set bootstrap_repo_url = 'https://' ~ salt['pillar.get']('mgr_server') ~ '/pub/repositories/ubuntu/' ~ osrelease[0] ~ '/' ~ osrelease[1].lstrip('0') ~ '/bootstrap/' %}
{%- elif grains['os'] == 'AstraLinuxCE' %}
{% set bootstrap_repo_url = 'https://' ~ salt['pillar.get']('mgr_server') ~ '/pub/repositories/astra/' ~ grains['oscodename'] ~ '/bootstrap/' %}
{%- else %}
{% set bootstrap_repo_url = 'https://' ~ salt['pillar.get']('mgr_server') ~ '/pub/repositories/debian/' ~ grains['osmajorrelease'] ~ '/bootstrap/' %}
{%- endif %}
{%- endif %}

{%- if not grains['os_family'] == 'Debian' %}

{%- set bootstrap_repo_request = salt['http.query'](bootstrap_repo_url + 'repodata/repomd.xml', status=True, verify_ssl=False) %}
{# 901 is a special status code for the TLS issue with RHEL6 and SLE11. #}
{%- if bootstrap_repo_request['status'] == 901 %}
{{ raise(bootstrap_repo_request['error']) }}
{%- endif %}
{%- set bootstrap_repo_exists = (0 < bootstrap_repo_request['status'] < 300) %}

bootstrap_repo:
  file.managed:
{%- if grains['os_family'] == 'Suse' %}
    - name: /etc/zypp/repos.d/susemanager:bootstrap.repo
{%- elif grains['os_family'] == 'RedHat' %}
    - name: /etc/yum.repos.d/susemanager:bootstrap.repo
{%- endif %}
    - source:
      - salt://bootstrap/bootstrap.repo
    - template: jinja
    - context:
      bootstrap_repo_url: {{bootstrap_repo_url}}
    - mode: 644
    - require:
      - host: mgr_server_localhost_alias_absent
{%- if repos_disabled.count > 0 %}
      - mgrcompat: disable_repo_*
{%- endif %}
    - onlyif:
      - ([ {{ bootstrap_repo_exists }} = "True" ])

{%- else %}
{%- set bootstrap_repo_exists = (0 < salt['http.query'](bootstrap_repo_url + 'dists/bootstrap/Release', status=True, verify_ssl=False)['status'] < 300) %}
bootstrap_repo:
  file.managed:
    - name: /etc/apt/sources.list.d/susemanager_bootstrap.list
    - source:
      - salt://bootstrap/bootstrap.repo
    - template: jinja
    - context:
      bootstrap_repo_url: {{bootstrap_repo_url}}
    - mode: 644
    - require:
      - host: mgr_server_localhost_alias_absent
{%- if repos_disabled.count > 0 %}
      - mgrcompat: disable_repo_*
{%- endif %}
    - onlyif:
      - ([ {{ bootstrap_repo_exists }} = "True" ])
{%- endif %}

{%- if grains['os_family'] == 'RedHat' %}
trust_res_gpg_key:
  cmd.run:
    - name: rpm --import https://{{ salt['pillar.get']('mgr_server') }}/pub/{{ salt['pillar.get']('gpgkeys:res:file') }}
    - unless: rpm -q {{ salt['pillar.get']('gpgkeys:res:name') }}
    - runas: root
{%- elif grains['os_family'] == 'Debian' %}
install_gnupg_debian:
  pkg.latest:
    - pkgs:
      - gnupg
{%- endif %}

{% include 'channels/gpg-keys.sls' %}

salt-minion-package:
  pkg.installed:
    - name: salt-minion
    - install_recommends: False
    - require:
      - file: bootstrap_repo

/etc/salt/minion.d/susemanager.conf:
  file.managed:
    - source:
      - salt://bootstrap/susemanager.conf
    - template: jinja
    - mode: 644
    - require:
      - pkg: salt-minion-package

/etc/salt/minion_id:
  file.managed:
    - contents_pillar: minion_id
    - require:
      - pkg: salt-minion-package

{% include 'bootstrap/remove_traditional_stack.sls' %}

mgr_update_basic_pkgs:
  pkg.latest:
    - pkgs:
      - openssl
{%- if grains['os_family'] == 'Suse' and grains['osrelease'] in ['11.3', '11.4'] and grains['cpuarch'] in ['i586', 'x86_64'] %}
      - pmtools
{%- elif grains['cpuarch'] in ['aarch64', 'x86_64'] %}
      - dmidecode
{%- endif %}
{%- if grains['os_family'] == 'Suse' %}
      - zypper
{%- elif grains['os_family'] == 'RedHat' %}
      - yum
{%- endif %}

# Manage minion key files in case they are provided in the pillar
{% if pillar['minion_pub'] is defined and pillar['minion_pem'] is defined %}
/etc/salt/pki/minion/minion.pub:
  file.managed:
    - contents_pillar: minion_pub
    - mode: 644
    - makedirs: True
    - require:
      - pkg: salt-minion-package

/etc/salt/pki/minion/minion.pem:
  file.managed:
    - contents_pillar: minion_pem
    - mode: 400
    - makedirs: True
    - require:
      - pkg: salt-minion-package

salt-minion:
  service.running:
    - enable: True
    - require:
      - pkg: salt-minion-package
      - host: mgr_server_localhost_alias_absent
    - watch:
      - file: /etc/salt/minion_id
      - file: /etc/salt/pki/minion/minion.pem
      - file: /etc/salt/pki/minion/minion.pub
      - file: /etc/salt/minion.d/susemanager.conf
{% else %}
salt-minion:
  service.running:
    - enable: True
    - require:
      - pkg: salt-minion-package
      - host: mgr_server_localhost_alias_absent
    - watch:
      - file: /etc/salt/minion_id
      - file: /etc/salt/minion.d/susemanager.conf
{% endif %}
