use Orbital::Transfer::Common::Setup;
package Orbital::CLI::Command::AppVeyor::Role::ProjectFromGitHubRemote;
# ABSTRACT: A role to retrieve the project associated with a GitHub remote

use Orbital::Transfer::Common::Setup;
use Moo::Role;
use List::AllUtils qw(first);

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

with qw(
	Orbital::CLI::Command::Role::GitHubRepos
	Orbital::CLI::Command::AppVeyor::Role::Client
);

1;
