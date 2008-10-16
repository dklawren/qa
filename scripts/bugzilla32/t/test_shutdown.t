use strict;
use warnings;
use lib qw(lib);

use Test::More "no_plan";

use QA::Util;

my ($sel, $config) = get_selenium();

log_in($sel, $config, 'admin');
set_parameters($sel, { "Required Settings" => {shutdownhtml => {type => "text",
                                                                value => "I'm down (set by test_shutdown.t)" }
                                              } });

# None of the following pages should be accessible when Bugzilla is down.

my @pages = qw(admin attachment buglist chart colchange config createaccount
               describecomponents describekeywords duplicates
               editclassifications editcomponents editfields editflagtypes
               editgroups editkeywords editmilestones editproducts editsettings
               editusers editvalues editversions editwhines editworkflow
               enter_bug index long_list page post_bug process_bug query quips
               relogin report reports request sanitycheck search_plugin
               show_activity show_bug showattachment showdependencygraph
               showdependencytree sidebar summarize_time token userprefs votes
               xml xmlrpc);

foreach my $page (@pages) {
    $sel->open_ok("/$config->{bugzilla_installation}/${page}.cgi");
    $sel->title_is("Bugzilla is Down");
}

# Those have parameters passed to the page, so we put them here separately.

@pages = ("query.cgi?format=report-table", "query.cgi?format=report-graph",
          "votes.cgi?action=show_user", "votes.cgi?action=show_bug");

foreach my $page (@pages) {
    $sel->open_ok("/$config->{bugzilla_installation}/$page");
    $sel->title_is("Bugzilla is Down");
}

# Clear 'shutdownhtml', to re-enable Bugzilla.
# At this point, the admin has been logged out. We cannot use log_in(),
# nor set_parameters(), due to shutdownhtml being active.

$sel->open_ok("/$config->{bugzilla_installation}/editparams.cgi");
$sel->title_is("Log in to Bugzilla");
$sel->type_ok("Bugzilla_login", $config->{admin_user_login}, "Enter admin login name");
$sel->type_ok("Bugzilla_password", $config->{admin_user_passwd}, "Enter admin password");
$sel->click_ok("log_in");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Configuration: Required Settings");
$sel->type_ok("shutdownhtml", "");
$sel->click_ok('//input[@type="submit" and @value="Save Changes"]', undef, "Save Changes");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Parameters Updated");

# Accessing index.cgi should work again now.

$sel->click_ok("link=Home");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Bugzilla Main Page");
logout($sel);
