Name:       perl-Collectd-Plugins-Compute
Version:    0.1001
Release:    0%{?dist}
Epoch:      0
# license auto-determination failed
License:    GPL
Group:      Development/Libraries
Summary:    Collectd plugin to compute new values from cache
Source:     Collectd-Plugins-Compute-%{version}.tar.gz
Url:        http://search.cpan.org/dist/Collectd-Plugins-Compute
BuildRoot:  %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n) 
Requires:   perl(:MODULE_COMPAT_%(eval "`%{__perl} -V:version`"; echo $version))
BuildArch:  noarch
AutoReq:    no

Requires: perl(Collectd)
Requires: perl(Collectd::Unixsock)
Requires: perl(Collectd::Plugins::Common)

BuildRequires: perl(Test::More)
BuildRequires: perl(Test::Collectd::Plugins)

%description
Collectd plugin to compute new values from cache.

%prep
%setup -q -n Collectd-Plugins-Compute-%{version}

%build
PERL_AUTOINSTALL=--skipdeps PERL_MM_USE_DEFAULT=1 %{__perl} Makefile.PL INSTALLDIRS=vendor
make %{?_smp_mflags}

%install
rm -rf %{buildroot}

make pure_install PERL_INSTALL_ROOT=%{buildroot}
find %{buildroot} -type f -name .packlist -exec rm -f {} ';'
find %{buildroot} -depth -type d -exec rmdir {} 2>/dev/null ';'

%{_fixperms} %{buildroot}/*

%check
make test

%clean
rm -rf %{buildroot} 

%files
%defattr(-,root,root,-)
%doc Changes README 
%{perl_vendorlib}/*
%{_mandir}/man3/*.3*

# output by: date +"* \%a \%b \%d \%Y $USER"
%changelog
* Mon Dec 10 2012 fwernli 0.1001
- release

