package Orbital::Launch::Environment::AppVeyor;
# ABSTRACT: AppVeyor CI environment

use Moo;

sub is_active {
	# See <https://www.appveyor.com/docs/environment-variables/>.
	return exists $ENV{APPVEYOR};
}

1;
