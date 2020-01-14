#
# spec file for package sapwmp2
#
# Copyright (c) 2020 SUSE LINUX GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name: sapwmp
Summary: Configuration for collecting SAP processes under control group
License: GPL-2.0
Version: 0.1
Release: 0
Group: Applications/System
Vendor: SUSE GmbH
BuildArch: noarch
URL: http://www.suse.com

Source0: cg_trans
Source1: sysconfig.sapwmp
Source2: service-wmp.conf
Source3: sap.slice

BuildRequires: systemd-rpm-macros
Requires: pam
Requires: util-linux-systemd
Requires: /bin/bash
Requires: /usr/bin/getent
%{?systemd_requires}

%description
Configuration for collecting SAP processes under control group to apply resource control.

%prep

%build

%install
install -m 744 %{SOURCE0} %{buildroot}/usr/sbin/
install -D -m 644 %{SOURCE2} %{buildroot}%{_unitdir}/sapinit.service.d/10-wmp.conf
install -D -m 644 %{SOURCE3} %{buildroot}%{_unitdir}/sap.slice
mkdir -p %{buildroot}%{_fillupdir}
install -m 0644 %{SOURCE1} %{buildroot}/%{_fillupdir}


%files
%defattr(-,root,root)
%config %{_fillupdir}/sysconfig.sapwmp
/usr/sbin/cg_trans
%{_unitdir}/sapinit.service.d/10-wmp.conf
%{_unitdir}/sap.slice
%{_fillupdir}/sysconfig.sapwmp
%doc

%post
%fillup_only -n sapwmp
if ! grep -q "added by %{name}" /etc/pam.d/common-session ; then
	echo "# line below added by %{name}, do not modify" >> /etc/pam.d/common-session
	echo "session optional        pam_exec.so quiet /usr/sbin/cg_trans debug" >> /etc/pam.d/common-session
fi
if grep -q " cgroup .*memory" /proc/mounts ; then
	echo "Warning: Found memory controller on v1 hierarchy. Make sure unified hierarchy only is used."
fi


%postun
if [ "$1" = 0 ] && grep -q "added by %{name}" /etc/pam.d/common-session ] ; then
	sed -i '/^# line below added by %{name}/,+1 d' /etc/pam.d/common-session
fi

%changelog
