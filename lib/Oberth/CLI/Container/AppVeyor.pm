use Modern::Perl;
package Oberth::CLI::Container::AppVeyor;
# ABSTRACT: Container for AppVeyor

use Oberth::Manoeuvre::Common::Setup;

method commands() {
	return +{
		'service/appveyor' => 'Oberth::CLI::Command::AppVeyor',
	}
}

1;
