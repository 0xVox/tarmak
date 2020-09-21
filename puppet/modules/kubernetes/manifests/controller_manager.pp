# class kubernetes::master
class kubernetes::controller_manager(
  $ca_file = undef,
  $cert_file = undef,
  $key_file = undef,
  $systemd_wants = [],
  $systemd_requires = [],
  $systemd_after = [],
  $systemd_before = [],
  Boolean $allocate_node_cidrs = false,
  Hash[String,Boolean] $feature_gates = {},
)  {
  require ::kubernetes

  $_systemd_wants = $systemd_wants
  $_systemd_requires = $systemd_requires
  $_systemd_after = ['network.target'] + $systemd_after
  $_systemd_before = $systemd_before

  $post_1_15 = versioncmp($::kubernetes::version, '1.15.0') >= 0
  $post_1_6 = versioncmp($::kubernetes::version, '1.6.0') >= 0

  $service_name = 'kube-controller-manager'

  if $post_1_15 {
    $command_name = 'kube-controller-manager'
  } else {
    $command_name = 'controller-manager'
  }

  $kubeconfig_path = "${::kubernetes::config_dir}/kubeconfig-controller-manager"

  $authorization_mode = $kubernetes::_authorization_mode

  $_feature_gates = $feature_gates

  if $::kubernetes::use_hyperkube {
      kubernetes::symlink{$command_name:}
  } else {
      include kubernetes::install
  }
  -> file{$kubeconfig_path:
    ensure  => file,
    mode    => '0640',
    owner   => 'root',
    group   => $kubernetes::group,
    content => template('kubernetes/kubeconfig.erb'),
    notify  => Service["${service_name}.service"],
  }

  file{"${::kubernetes::systemd_dir}/${service_name}.service":
    ensure  => file,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => template("kubernetes/${service_name}.service.erb"),
    notify  => Service["${service_name}.service"],
  }
  ~> exec { "${service_name}-daemon-reload":
    command     => 'systemctl daemon-reload',
    path        => $::kubernetes::path,
    refreshonly => true,
  }
  -> service{ "${service_name}.service":
    ensure => running,
    enable => true,
  }

}
