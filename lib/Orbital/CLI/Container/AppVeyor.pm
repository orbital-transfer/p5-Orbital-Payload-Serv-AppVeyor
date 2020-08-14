use Modern::Perl;
package Orbital::CLI::Container::AppVeyor;
# ABSTRACT: Container for AppVeyor

use Orbital::Transfer::Common::Setup;

method commands() {
	return +{
		'service/appveyor' => 'Orbital::CLI::Command::AppVeyor',
	}
}

1;
