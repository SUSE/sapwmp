#
# spec file for package sapwmp
#
# Copyright (c) 2020 SUSE LLC
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via https://bugs.opensuse.org/
#


%define group_sapsys sapsys
Name:           sapwmp
Version:        0.1
Release:        0
Summary:        Configuration and utilities for collecting SAP processes under control group
License:        GPL-2.0-only
Group:          Productivity/Databases/Servers
%if 0%{?sle_version} == 150000
URL:            https://documentation.suse.com/sles-sap/15-GA/html/SLES4SAP-guide/cha-s4s-tune.html#sec-s4s-memory-protection
%endif
%if 0%{?sle_version} == 150100
URL:            https://documentation.suse.com/sles-sap/15-SP1/html/SLES4SAP-guide/cha-s4s-tune.html#sec-s4s-memory-protection
%endif
%if 0%{?sle_version} >= 150200
URL:            https://documentation.suse.com/sles-sap/15-SP2/html/SLES-SAP-guide/cha-tune.html#sec-memory-protection
%endif
Source0:        %{name}-%{version}.tar.xz
BuildRequires:  autoconf
BuildRequires:  automake
BuildRequires:  systemd-devel
BuildRequires:  systemd-rpm-macros
Requires(post): %fillup_prereq
Requires(post): permissions
Requires:       util-linux-systemd
# We need kernel fix for bsc#1174002
%if 0%{?sle_version} == 150200
Requires:       kernel >= 5.3.18-24.12
%endif
%{?systemd_requires}

%description
Configuration and utilities for collecting SAP processes under control group to apply resource control.

%prep
%setup -q

%build
./autogen.sh
%configure
# make_build not defined in SLE12, so need conditions to check
%if "x%{?make_build}" != "x"
%make_build
%else
%{__make} %{?jobs:-j%jobs}%{?!jobs:%{?_smp_mflags:%_smp_mflags}}
%endif


%install
%make_install
%define wmpd %{_builddir}/%{name}-%{version}
install -D -m 644 %{wmpd}/rpm/sapwmp.conf %{buildroot}/%{_sysconfdir}/sapwmp.conf
install -D -m 644 %{wmpd}/rpm/SAP.slice %{buildroot}/%{_unitdir}/SAP.slice
install -D -m 755 %{wmpd}/rpm/supportconfig-sapwmp %{buildroot}%{_prefix}/lib/supportconfig/plugins/sapwmp
install -D -m 744 %{wmpd}/rpm/wmp-sample-memory.sh %{buildroot}/%{_libexecdir}/sapwmp/wmp-sample-memory
install -D -m 644 %{wmpd}/rpm/wmp-sample-memory.service %{buildroot}/%{_unitdir}/wmp-sample-memory.service
install -D -m 644 %{wmpd}/rpm/wmp-sample-memory.timer %{buildroot}/%{_unitdir}/wmp-sample-memory.timer

mkdir -p %{buildroot}/%{_libexecdir}/sapwmp/scripts
install -D -m 755 %{wmpd}/scripts/*.sh %{buildroot}/%{_libexecdir}/sapwmp/scripts/

mkdir -p %{buildroot}/%{_defaultdocdir}/sapwmp
install -D -m 644 %{wmpd}/scripts/README* %{buildroot}/%{_defaultdocdir}/sapwmp

%verifyscript
%verify_permissions -e %{_libexecdir}/sapwmp/sapwmp-capture

%pre
getent group %{group_sapsys} >/dev/null || cat <<EOD
The %{group_sapsys} group was not found! Most probably because no SAP software
is installed on your system. The ownership of some files are not sufficient
now.
To fix this, run the following commands after installing the SAP
software, which should create the group %{group_sapsys}:

chgrp %{group_sapsys} %{_libexecdir}/sapwmp/sapwmp-capture
chmod +s %{_libexecdir}/sapwmp/sapwmp-capture
EOD
%service_add_pre wmp-sample-memory.service wmp-sample-memory.timer

%post
%set_permissions %{_libexecdir}/sapwmp/sapwmp-capture
# Historically, we used 'sap.slice', check if there is any user configuration
# set with systemctl set-property and reassign to the current 'SAP.slice' (keep
# runtime copy for 'sap.slice').
# systemctl-daemon reload is implicit in the following service_add_post.
if [ "$1" -eq "2" -a -d /etc/systemd/system.control/sap.slice.d ] ; then
	cp -r /etc/systemd/system.control/sap.slice.d /run/systemd/system.control/sap.slice.d || :
	mv /etc/systemd/system.control/sap.slice.d /etc/systemd/system.control/SAP.slice.d \
	 && echo "Migrated configuration from sap.slice to SAP.slice"
fi
%service_add_post wmp-sample-memory.service wmp-sample-memory.timer
if grep -q " cgroup .*memory" /proc/mounts ; then
	echo "Warning: Found memory controller on v1 hierarchy. Make sure unified hierarchy only is used."
fi

%preun
%service_del_preun wmp-sample-memory.service wmp-sample-memory.timer

%postun
%service_del_postun wmp-sample-memory.service wmp-sample-memory.timer

%files
%dir %{_libexecdir}/sapwmp
%verify(not user group mode) %attr(4750,root,%{group_sapsys}) %{_libexecdir}/sapwmp/sapwmp-capture
%{_libexecdir}/sapwmp/wmp-sample-memory
%{_unitdir}/SAP.slice
%{_unitdir}/wmp-sample-memory.service
%{_unitdir}/wmp-sample-memory.timer
%config %{_sysconfdir}/sapwmp.conf
%dir %{_prefix}/lib/supportconfig
%dir %{_prefix}/lib/supportconfig/plugins
%{_prefix}/lib/supportconfig/plugins/sapwmp
%{_libexecdir}/sapwmp/scripts
%{_defaultdocdir}/sapwmp

%changelog
