use Orbital::Transfer::Common::Setup;
package Orbital::CLI::Command::AppVeyor::FixGitHubPermHack;
# ABSTRACT: A temporary subcommand for GitHub permissions

use Moo;
use CLI::Osprey;
use utf8;

use JSON::MaybeXS;
use Term::ANSIColor;
use Text::Table;

has github_org_appveyor_role_map => (
	is => 'ro',
	default => sub {
		my $github_org_to_appveyor_role = {
			#'EntropyOrg' =>
			'orbital-transfer' => 'orbital-transfer',
			'PDLPorters' => 'PDLPorters',
			'project-renard' => 'project-renard',
			#'zmughal-p5CPAN' =>
		};
	},
);

method fix_permissions_for_project( $project ) {
	my $github_org_to_appveyor_role = $self->github_org_appveyor_role_map;

	my $gh_slug = $project->{repositoryName};
	my ($org) = $gh_slug =~ m,^([^/]+)/[^/]+$,;
	say "$project->{repositoryName} of org $org";
	say "\thas associated role $github_org_to_appveyor_role->{$org}" if( exists $github_org_to_appveyor_role->{$org} );

	my $settings = $self->_get_project_settings( $project );

	my $roleAces = $settings->{settings}{securityDescriptor}{roleAces};

	for my $aces (@$roleAces) {
		# Can not change Admin access
		next if $aces->{isAdmin};

		# User should be Inherit x 4
		next if $aces->{name} eq 'User';

		# if org of repo has a role,
		# Make that role, Allow x 4
		# All other roles should be Deny x 4

		my $allowed_value =
			exists $github_org_to_appveyor_role->{$org}
			&& $aces->{name} eq $github_org_to_appveyor_role->{$org}
			? JSON->true
			: JSON->false;

		$_->{allowed} = $allowed_value  for @{ $aces->{accessRights} };
	}

	#use XXX; XXX $settings->{settings}{securityDescriptor}{roleAces};

	$self->_put( '/projects', $settings->{settings} );
}

subcommand 'for-all-projects' => method() {
	my $projects = $self->_get( '/projects' );
	for my $project (@$projects) {
		next unless $project->{repositoryType} eq 'gitHub';

		$self->fix_permissions_for_project( $project );
	}
};

subcommand 'list' => method() {
	my $gh_slug = $self->_get_github_slug;
	my $project_repo = $self->_get_project( $gh_slug );
	return unless $project_repo;

	my $settings = $self->_get_project_settings( $project_repo );

	my $roleAces = $settings->{settings}{securityDescriptor}{roleAces};

	my @names = map { { title => $_->{name}, align_title => 'center', } } @{ $roleAces->[0]{accessRights} };
	my $table = Text::Table->new( { title => 'Name', align => 'left' }, @names );

	$table->load(
		map {
			my $role = $_;
			[
			$role->{name},
			map {
				colored("•",
					! exists $_->{allowed}
					? "reset"
					: $_->{allowed} ? 'green' : 'red'
				)
			} @{ $role->{accessRights} } ]
		} @$roleAces
	);
	binmode STDOUT, ':encoding(UTF-8)';
	print $table;
};

method run() {
	my $gh_slug = $self->_get_github_slug;
	my $project_repo = $self->_get_project( $gh_slug );
	return unless $project_repo;

	$self->fix_permissions_for_project( $project_repo );
};

with qw(
	Orbital::CLI::Command::AppVeyor::Role::Client
	Orbital::CLI::Command::AppVeyor::Role::ProjectFromGitHubRemote
);


1;
