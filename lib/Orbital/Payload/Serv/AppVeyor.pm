use Orbital::Transfer::Common::Setup;
package Orbital::Payload::Serv::AppVeyor;
# ABSTRACT: Interface to AppVeyor

use Moo;

use JSON::MaybeXS;
use LWP::UserAgent;

has token => ( is => 'lazy' );

use constant APPVEYOR_API_ENDPONT => 'https://ci.appveyor.com/api';

method _build_token() {
	my $token = `git config --global orbital.appveyor-token`;
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
		APPVEYOR_API_ENDPONT . $endpoint,
		Content => encode_json($payload)
	);

	die "POST $endpoint failed: @{[ $response->decoded_content ]}" unless $response->is_success;

	my $response_json = decode_json($response->decoded_content);
}

method _put($endpoint, $payload ) {
	my $response = $self->_ua->put(
		APPVEYOR_API_ENDPONT . $endpoint,
		Content => encode_json($payload)
	);

	die "PUT $endpoint failed: @{[ $response->decoded_content ]}" unless $response->is_success;
}

method _get($endpoint) {
	my $response = $self->_ua->get(
		APPVEYOR_API_ENDPONT . $endpoint,
	);

	die "GET $endpoint failed: @{[ $response->decoded_content ]}" unless $response->is_success;

	my $response_json = decode_json($response->decoded_content);
}

method _delete($endpoint ) {
	my $response = $self->_ua->delete(
		APPVEYOR_API_ENDPONT . $endpoint,
	);

	die "DELETE $endpoint failed: @{[ $response->decoded_content ]}" unless $response->is_success;
}

method _get_build_history($project_repo) {
	my $records_per_page = 30;
	my $history = $self->_get(
		"/projects/@{[ $project_repo->{accountName} ]}/@{[ $project_repo->{slug} ]}"
		.
		"/history?recordsNumber=$records_per_page"
		# [&startBuildId={buildId}&branch={branch}]
	);
}

method _get_project_settings( $project_repo ) {
	my $settings = $self->_get( "/projects/@{[ $project_repo->{accountName} ]}/@{[ $project_repo->{slug} ]}/settings" );
}

1;
