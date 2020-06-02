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
URL:            https://gitlab.suse.de/mkoutny/wmp-repo/
Source0:        %{name}-%{version}.tar.xz
Source1:        sapwmp.conf
Source2:        sap.slice
Source3:        supportconfig-sapwmp
BuildRequires:  autoconf
BuildRequires:  automake
BuildRequires:  systemd-devel
BuildRequires:  systemd-rpm-macros
Requires(post): %fillup_prereq
Requires(post): permissions
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
install -D -m 644 %{SOURCE2} %{buildroot}/%{_unitdir}/sap.slice
install -D -m 755 %{SOURCE3} %{buildroot}/usr/lib/supportconfig/plugins/sapwmp

%verifyscript
%verify_permissions -e %{_libexecdir}/sapwmp/sapwmp-capture

%pre
getent group %{group_sapsys} >/dev/null || echo "Warning: %{group_sapsys} group not found"
%service_add_pre sap.slice

%post
%set_permissions %{_libexecdir}/sapwmp/sapwmp-capture
%service_add_post sap.slice
if grep -q " cgroup .*memory" /proc/mounts ; then
	echo "Warning: Found memory controller on v1 hierarchy. Make sure unified hierarchy only is used."
fi

%preun
%service_del_preun sap.slice

%postun
%service_del_postun sap.slice

%files
%dir %{_libexecdir}/sapwmp
%verify(not user group mode) %attr(4750,root,%{group_sapsys}) %{_libexecdir}/sapwmp/sapwmp-capture
%{_unitdir}/sap.slice
%config %{_sysconfdir}/sapwmp.conf
%dir /usr/lib/supportconfig
%dir /usr/lib/supportconfig/plugins
/usr/lib/supportconfig/plugins/sapwmp


%changelog
