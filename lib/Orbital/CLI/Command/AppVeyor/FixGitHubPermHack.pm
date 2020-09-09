use Orbital::Transfer::Common::Setup;
package Orbital::CLI::Command::AppVeyor::FixGitHubPermHack;
# ABSTRACT: A temporary subcommand for GitHub permissions

use Moo;
use CLI::Osprey;

use JSON::MaybeXS;

method run() {
	my $github_org_to_appveyor_role = {
		#'EntropyOrg' =>
		'orbital-transfer' => 'orbital-transfer',
		'PDLPorters' => 'PDLPorters',
		'project-renard' => 'project-renard',
		#'zmughal-p5CPAN' =>
	};
	my $client = $self->parent_command;
	my $projects = $client->_get( '/projects' );
	for my $project (@$projects) {
		next unless $project->{repositoryType} eq 'gitHub';
		my $gh_slug = $project->{repositoryName};
		my ($org) = $gh_slug =~ m,^([^/]+)/[^/]+$,;
		say "$project->{repositoryName} of org $org";
		say "\thas associated role $github_org_to_appveyor_role->{$org}" if( exists $github_org_to_appveyor_role->{$org} );

		my $settings = $client->_get_project_settings( $project );

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

		$client->_put( '/projects', $settings->{settings} );
	}
};

1;
