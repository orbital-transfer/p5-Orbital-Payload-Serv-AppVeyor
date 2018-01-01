use Oberth::Common::Setup;
package Oberth::CLI::Command::AppVeyor;
# ABSTRACT: A command for AppVeyor

use Moo;
use CLI::Osprey;
use JSON::MaybeXS;
use LWP::UserAgent;
use List::AllUtils qw(first);

has token => ( is => 'lazy' );

method _build_token() {
	my $token = `git config --global oberth.appveyor-token`;
	chomp $token;

	$token;
}

has _ua => ( is => 'lazy' );

method _build__ua() {
	my $ua = LWP::UserAgent->new;
	$ua->default_header( Authorization => 'Bearer '. $self->token );
	$ua->default_header( 'Content-Type' => 'application/json' );
	$ua->default_header( Accept => 'application/json' );

	$ua;
}

method _post($endpoint, $payload ) {
	my $response = $self->_ua->post(
		'https://ci.appveyor.com/api'. $endpoint,
		Content => encode_json($payload)
	);

	die "POST $endpoint failed: @{[ $response->decoded_content ]}" unless $response->is_success;

	my $response_json = decode_json($response->decoded_content);
}

method _put($endpoint, $payload ) {
	my $response = $self->_ua->put(
		'https://ci.appveyor.com/api'. $endpoint,
		Content => encode_json($payload)
	);

	die "PUT $endpoint failed: @{[ $response->decoded_content ]}" unless $response->is_success;
}

method _get($endpoint) {
	my $response = $self->_ua->get(
		'https://ci.appveyor.com/api'. $endpoint,
	);

	die "GET $endpoint failed: @{[ $response->decoded_content ]}" unless $response->is_success;

	my $response_json = decode_json($response->decoded_content);
}

subcommand enable => method() {
	my $gh = $self->github_repo_origin;
	my $projects = $self->_get( '/projects' );

	my $gh_slug = $gh->namespace . "/" . $gh->name;
	my $project_repo = first {
		$_->{repositoryType} eq 'gitHub'
		&& $_->{repositoryName} eq $gh_slug,
	} @$projects;

	unless( $project_repo ) {
		say "Enabling new repo for $gh_slug";
		$project_repo = $self->_post( '/projects', {
			repositoryProvider => "gitHub",
			repositoryName => $gh_slug,
		});
	} else {
		say "Repo for $gh_slug already on AppVeyor";
	}

	my $settings = $self->_get( "/projects/@{[ $project_repo->{accountName} ]}/@{[ $project_repo->{slug} ]}/settings" );
	unless( $settings->{settings}{name} eq $gh_slug && $settings->{settings}{skipBranchesWithoutAppveyorYml} ) {
		say "Updating the project name to match $gh_slug and ensuring skipBranchesWithoutAppveyorYml is true";

		$settings->{settings}{name} = $gh_slug;
		$settings->{settings}{skipBranchesWithoutAppveyorYml} = JSON->true;

		$self->_put( '/projects', $settings->{settings} );
	}
};

with qw(Oberth::CLI::Command::Role::GitHubRepos);

1;
