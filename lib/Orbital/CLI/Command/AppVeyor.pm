use Orbital::Transfer::Common::Setup;
package Orbital::CLI::Command::AppVeyor;
# ABSTRACT: A command for AppVeyor

use Moo;
use CLI::Osprey (
	desc => 'AppVeyor CI'
);
use JSON::MaybeXS;
use Term::ANSIColor;
use Browser::Open qw(open_browser);
use List::AllUtils qw(first);

subcommand 'status-badge' => method() {
	my $gh_slug = $self->_get_github_slug;
	my $project_repo = $self->_get_project( $gh_slug );
	return unless $project_repo;

	my $settings = $self->_get_project_settings($project_repo);
	say "https://ci.appveyor.com/api/projects/status/@{[ $settings->{settings}{statusBadgeId} ]}/branch/master?svg=true";
};

subcommand 'builds' => method() {
	my $gh_slug = $self->_get_github_slug;
	my $project_repo = $self->_get_project( $gh_slug );
	return unless $project_repo;

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
	return unless $project_repo;

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
		my $response = $self->_client->_ua->get(
			Orbital::Payload::Service::AppVeyor::APPVEYOR_API_ENDPONT() . "/buildjobs/$first_job_id/log",
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
	return unless $project_repo;

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

subcommand 'delete-project' => method() {
	my $gh_slug = $self->_get_github_slug;
	my $project_repo = $self->_get_project( $gh_slug );
	return unless $project_repo;

	die "Project not on AppVeyor" unless( $project_repo );

	$self->_delete(
		"/projects/@{[ $project_repo->{accountName} ]}/@{[ $project_repo->{slug} ]}"
	);

	say "Repo $gh_slug AppVeyor project deleted";
};

subcommand 'open-in-browser' => method() {
	my $gh_slug = $self->_get_github_slug;
	my $project_repo = $self->_get_project( $gh_slug );
	return unless $project_repo;

	my $url = join "/", 'https://ci.appveyor.com/project', $project_repo->{accountName},  $project_repo->{slug};
	open_browser( $url );
};

subcommand 'list-github-projects' => method() {
	my $projects = $self->_get( '/projects' );
	for my $project (@$projects) {
		next unless $project->{repositoryType} eq 'gitHub';
		say "$project->{repositoryName}"
	}
};

subcommand 'fix-github-permissions-hack'
	=> 'Orbital::CLI::Command::AppVeyor::FixGitHubPermHack';

with qw(
	Orbital::CLI::Command::AppVeyor::Role::Client
	Orbital::CLI::Command::AppVeyor::Role::ProjectFromGitHubRemote
);

1;
