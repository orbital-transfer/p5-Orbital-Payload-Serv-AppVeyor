use Orbital::Transfer::Common::Setup;
package Orbital::CLI::Command::AppVeyor::Role::Client;
# ABSTRACT: A role to provide client methods

use Moo::Role;
use Orbital::Payload::Service::AppVeyor;

has _client => (
	is => 'ro',
	default => sub { Orbital::Payload::Service::AppVeyor->new },
	handles => [ qw(
		_post _put _get _delete
		_get_build_history _get_project_settings
	) ],
);

1;
