use strict;
use warnings;
use lib qw(lib);

use Test::WWW::Selenium;
use Test::More "no_plan";

use QA::Util;

my $conf_file = "../config/selenium_test.conf";

# read the test configuration file
my $config = do "$conf_file"
    or die "can't read configuration '$conf_file': $!$@";

my $sel = Test::WWW::Selenium->new(
    host        => $config->{host},
    browser     => $config->{browser},
    browser_url => $config->{browser_url}
);

# Very simple test script to test if bug creation with minimal data passes successfully,
# for different user privileges.
# More elaborated tests exist in other scripts. This doesn't mean this one could not
# be improved a bit.

foreach my $user (qw(admin unprivileged canconfirm)) {
    log_in($sel, $config, $user);
    file_bug_in_product($sel, "TestProduct");
    $sel->type_ok("short_desc", "Bug created by Selenium", "Enter bug summary");
    $sel->type_ok("comment", "--- Bug created by Selenium ---", "Enter bug description");
    $sel->click_ok("commit", undef, "Submit bug data to post_bug.cgi");
    $sel->wait_for_page_to_load(30000);
    $sel->title_like(qr/Bug \d+ Submitted/, "Bug created");
    $sel->open_ok("/$config->{bugzilla_installation}/relogin.cgi", undef, "Logout");
}
