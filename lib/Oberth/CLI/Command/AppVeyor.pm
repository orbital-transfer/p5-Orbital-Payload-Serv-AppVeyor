use Oberth::Common::Setup;
package Oberth::CLI::Command::AppVeyor;
# ABSTRACT: A command for AppVeyor

use Moo;
use CLI::Osprey;
use JSON::MaybeXS;
use LWP::UserAgent;
use List::AllUtils qw(first);
use Term::ANSIColor;

has token => ( is => 'lazy' );

use constant APPVEYOR_API_ENDPONT => 'https://ci.appveyor.com/api';

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

method _get_github_slug() {
	my $gh = $self->github_repo_origin;
	my $gh_slug = $gh->namespace . "/" . $gh->name;
}

method _get_project($gh_slug) {
	my $projects = $self->_get( '/projects' );
	my $project_repo = first {
		$_->{repositoryType} eq 'gitHub'
		&& $_->{repositoryName} eq $gh_slug,
	} @$projects;

	$project_repo;
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

subcommand 'status-badge' => method() {
	my $gh_slug = $self->_get_github_slug;
	my $project_repo = $self->_get_project( $gh_slug );
	my $settings = $self->_get_project_settings($project_repo);
	say "https://ci.appveyor.com/api/projects/status/@{[ $settings->{settings}{statusBadgeId} ]}/branch/master?svg=true";
};

subcommand 'builds' => method() {
	my $gh_slug = $self->_get_github_slug;
	my $project_repo = $self->_get_project( $gh_slug );

	my $history = $self->_get_build_history($project_repo);
	for my $build (@{ $history->{builds} }) {
		my $url = "https://ci.appveyor.com/project/@{[ $project_repo->{accountName} ]}/@{[ $project_repo->{slug} ]}/build/@{[ $build->{version} ]}";
		say sprintf(
			"%s "
			. colored("%-14s",
				$build->{status} eq 'queued'   ? 'cyan'
				: $build->{status} eq 'failed' ? 'red'
				: $build->{status} eq 'success' ? 'green'
				: $build->{status} eq 'running' ? 'yellow bold'
				: $build->{status} eq 'cancelled' ? 'white'
				: 'reset'
			)
			. colored("%s", 'yellow')
			. " %s: <%s>",
			$build->{version},
			$build->{status} . ":" ,
			$build->{branch} .  (exists $build->{pullRequestId} ? " (PR #@{[ $build->{pullRequestId} ]})" : ""),
			$build->{message},
			$url
		);
	}
};

subcommand 'last-build-log' => method() {
	my $gh_slug = $self->_get_github_slug;
	my $project_repo = $self->_get_project( $gh_slug );

	my $history = $self->_get_build_history($project_repo);
	my $first_build = first {
		$_->{status} ne 'queued'
	} @{ $history->{builds} };

	my $first_build_info = $self->_get(
		"/projects/@{[ $project_repo->{accountName} ]}/@{[ $project_repo->{slug} ]}"
		.
		"/build/@{[ $first_build->{version} ]}"
	);

	my $first_job = first {
		$_->{status} ne 'queued'
	} reverse @{ $first_build_info->{build}{jobs} };
	my $first_job_id = $first_job->{jobId};


	{
		local($\) = ""; # ensure standard $OUTPUT_RECORD_SEPARATOR
		my $callback = sub { print $_[0] };
		my $response = $self->_ua->get(
			APPVEYOR_API_ENDPONT . "/buildjobs/$first_job_id/log",
			':content_cb' => $callback,
		);
		unless ($response->is_success) {
			die "Could not get last build log: " . $response->decoded_content;
		}
	}
};

subcommand 'clear-cache' => method() {
	my $gh_slug = $self->_get_github_slug;
	my $project_repo = $self->_get_project( $gh_slug );

	die "Project not on AppVeyor" unless( $project_repo );

	$self->_delete(
		"/projects/@{[ $project_repo->{accountName} ]}/@{[ $project_repo->{slug} ]}/buildcache"
	);

	say "Repo $gh_slug AppVeyor cache cleared";
};

subcommand enable => method() {
	my $gh_slug = $self->_get_github_slug;
	my $project_repo = $self->_get_project( $gh_slug );
	unless( $project_repo ) {
		say "Enabling new repo for $gh_slug";
		$project_repo = $self->_post( '/projects', {
			repositoryProvider => "gitHub",
			repositoryName => $gh_slug,
		});
	} else {
		say "Repo for $gh_slug already on AppVeyor";
	}

	my $settings = $self->_get_project_settings($project_repo);
	unless( $settings->{settings}{name} eq $gh_slug && $settings->{settings}{skipBranchesWithoutAppveyorYml} ) {
		say "Updating the project name to match $gh_slug and ensuring skipBranchesWithoutAppveyorYml is true";

		$settings->{settings}{name} = $gh_slug;
		$settings->{settings}{skipBranchesWithoutAppveyorYml} = JSON->true;

		$self->_put( '/projects', $settings->{settings} );
	}
};

with qw(Oberth::CLI::Command::Role::GitHubRepos);

1;
