use Orbital::Transfer::Common::Setup;
package Orbital::CLI::Container::AppVeyor;
# ABSTRACT: Container for AppVeyor

method commands() {
	return +{
		'service/appveyor' => 'Orbital::CLI::Command::AppVeyor',
	}
}

1;
