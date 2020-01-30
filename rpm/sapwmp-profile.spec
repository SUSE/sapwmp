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

Source0: polkit.rules
Source1: sysconfig.sapwmp
Source2: service-wmp.conf
Source3: sap.slice

BuildRequires: systemd-rpm-macros #TODO review
BuildRequires: systemd-devel #TODO review
Requires: util-linux-systemd #TODO review
Requires: /bin/bash #TODO review
Requires: /usr/bin/getent #TODO review
Requires(post): %fillup_prereq #TODO review
%{?systemd_requires} #TODO review

%description
Configuration for collecting SAP processes under control group to apply resource control.

%prep
%setup -q

%build
./autogen.sh
%configure
%make_build

%install
%make_install
install -D -m 744 %{SOURCE0} %{buildroot}/usr/share/polkit-1/rules.d/50-sapwmp.rules
install -D -m 644 %{SOURCE1} %{buildroot}/%{_fillupdir}/sysconfig.sapwmp
install -D -m 644 %{SOURCE2} %{buildroot}%{_unitdir}/sapinit.service.d/10-wmp.conf
install -D -m 644 %{SOURCE3} %{buildroot}%{_unitdir}/sap.slice


%files
%defattr(-,root,root)
%config %{_fillupdir}/sysconfig.sapwmp
%dir %{_unitdir}/sapinit.service.d
%{_unitdir}/sapinit.service.d/10-wmp.conf
%{_unitdir}/sap.slice
%{_fillupdir}/sysconfig.sapwmp
/usr/share/polkit-1/rules.d/50-sapwmp.rules
%doc

%post
%fillup_only -n sapwmp
# TODO make sure we're compatible with common-session-pc
if grep -q " cgroup .*memory" /proc/mounts ; then
	echo "Warning: Found memory controller on v1 hierarchy. Make sure unified hierarchy only is used."
fi
# TODO reload/restart polkit


%postun
# TODO reload/restart polkit

%changelog
