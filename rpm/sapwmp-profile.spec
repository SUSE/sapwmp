#
# spec file for package sapwmp-profile
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

%define group_sapsys sapsys

Name: sapwmp-profile
Summary: Configuration and utilities for collecting SAP processes under control group
License: GPL-2.0
Version: 0.1
Release: 0
Group: Productivity/Databases/Servers
Vendor: SUSE GmbH
URL: http://www.suse.com

Source0: %{name}-%{version}.tar.xz
Source1: sapwmp.conf
Source2: service-wmp.conf
Source3: sap.slice

BuildRequires: autoconf
BuildRequires: automake
BuildRequires: systemd-rpm-macros
BuildRequires: systemd-devel
Requires(post): %fillup_prereq
%{?systemd_requires}

%description
Configuration and utilities for collecting SAP processes under control group to apply resource control.

%prep
%setup -q

%build
./autogen.sh
%configure
%make_build

%install
%make_install
install -D -m 644 %{SOURCE1} %{buildroot}/%{_sysconfdir}/sapwmp.conf
install -D -m 644 %{SOURCE2} %{buildroot}%{_unitdir}/sapinit.service.d/10-wmp.conf
install -D -m 644 %{SOURCE3} %{buildroot}%{_unitdir}/sap.slice


%files
%defattr(-,root,root)
%attr(1750,root,%{group_sapsys}) %{_sbindir}/sapwmp-capture
%dir %{_unitdir}/sapinit.service.d
%{_unitdir}/sapinit.service.d/10-wmp.conf
%{_unitdir}/sap.slice
%config %{_sysconfdir}/sapwmp.conf
%doc

%pre
getent group %{group_sapsys} >/dev/null || echo "Warning: %{group_sapsys} group not found"
%service_add_pre sap.slice

%post
if grep -q " cgroup .*memory" /proc/mounts ; then
	echo "Warning: Found memory controller on v1 hierarchy. Make sure unified hierarchy only is used."
fi
%service_add_post sap.slice

%preun
%service_del_preun sap.slice

%postun
%service_del_postun sap.slice

%changelog
