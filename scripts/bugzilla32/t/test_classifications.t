use strict;
use warnings;
use lib qw(lib);

use Test::More "no_plan";

use QA::Util;

my ($sel, $config) = get_selenium();

# Enable classifications

log_in($sel, $config, 'admin');
set_parameters($sel, { "Bug Fields" => {"useclassification-on" => undef} });

# Create a new classification.

$sel->click_ok("link=Administration");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Administer your installation/, "Display admin.cgi");
$sel->click_ok("link=Classifications");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Select classification");

# Delete old classifications if this script failed.
# Accessing action=delete directly must 1) trigger the security check page,
# and 2) automatically reclassify products in this classification.
if ($sel->is_text_present("cone")) {
    $sel->open_ok("/$config->{bugzilla_installation}/editclassifications.cgi?action=delete&amp;classification=cone");
    $sel->title_is("Suspicious Action");
    $sel->click_ok("confirm");
    $sel->wait_for_page_to_load_ok(WAIT_TIME);
    $sel->title_is("Classification Deleted");
}
if ($sel->is_text_present("ctwo")) {
    $sel->open_ok("/$config->{bugzilla_installation}/editclassifications.cgi?action=delete&amp;classification=ctwo");
    $sel->title_is("Suspicious Action");
    $sel->click_ok("confirm");
    $sel->wait_for_page_to_load_ok(WAIT_TIME);
    $sel->title_is("Classification Deleted");
}

$sel->click_ok("link=Add");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Add new classification");
$sel->type_ok("classification", "cone");
$sel->type_ok("description", "Classification number 1");
$sel->click_ok('//input[@type="submit" and @value="Add"]');
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("New Classification Created");

# Add TestProduct to the new classification. There should be no other
# products in this classification.

$sel->select_ok("prodlist", "value=TestProduct");
$sel->click_ok("add_products");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Reclassify products");
my @products = $sel->get_select_options("myprodlist");
ok(scalar @products == 1 && $products[0] eq 'TestProduct', "TestProduct successfully added to 'cone'");

# Create a new bug in this product/classification.

file_bug_in_product($sel, 'TestProduct', 'cone');
$sel->type_ok("short_desc", "Bug in classification cone");
$sel->type_ok("comment", "Created by Selenium with classifications turned on");
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/Bug \d+ Submitted/, "Bug created");
my $bug1_id = $sel->get_value('//input[@name="id" and @type="hidden"]');

# Rename 'cone' to 'Unclassified', which must be rejected as it already exists,
# then to 'ctwo', which is not yet in use. Should work fine, even with products
# already in it.

$sel->click_ok("link=Administration");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Administer your installation/, "Display admin.cgi");
$sel->click_ok("link=Classifications");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Select classification");
$sel->click_ok("link=cone");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Edit classification");
$sel->type_ok("classification", "Unclassified");
$sel->click_ok("//input[\@value='Update']");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Classification Already Exists");
$sel->go_back_ok();
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Edit classification");
$sel->type_ok("classification", "ctwo");
$sel->click_ok("//input[\@value='Update']");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Classification Updated");

# The classification the bug belongs to is no longer displayed since bug 452733.
# Keeping the code here in case it comes back in a future release. :)
# $sel->type_ok("quicksearch_top", $bug1_id);
# $sel->click_ok("find_top");
# $sel->wait_for_page_to_load_ok(WAIT_TIME);
# $sel->title_like(qr/^Bug $bug1_id /);
# $sel->is_text_present('[ctwo]');

# Now try to delete the 'ctwo' classification. It should fail as there are
# products in it.

$sel->click_ok("link=Administration");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Administer your installation/, "Display admin.cgi");
$sel->click_ok("link=Classifications");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Select classification");
$sel->click_ok('//a[@href="editclassifications.cgi?action=del&classification=ctwo"]');
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Error");
my $error = trim($sel->get_text("error_msg"));
ok($error =~ /there are products for this classification/, "Reject classification deletion");

# Reclassify the product before deleting the classification.

$sel->go_back_ok();
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Select classification");
$sel->click_ok('//a[@href="editclassifications.cgi?action=reclassify&classification=ctwo"]');
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Reclassify products");
$sel->add_selection_ok("myprodlist", "label=TestProduct");
$sel->click_ok("remove_products");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Reclassify products");
$sel->click_ok("link=edit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Select classification");
$sel->click_ok('//a[@href="editclassifications.cgi?action=del&classification=ctwo"]');
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Delete classification");
$sel->is_text_present_ok("Do you really want to delete this classification?");
$sel->click_ok("//input[\@value='Yes, delete']");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Classification Deleted");

# Disable classifications and make sure you cannot edit them anymore.

set_parameters($sel, { "Bug Fields" => {"useclassification-off" => undef} });
$sel->open_ok("/$config->{bugzilla_installation}/editclassifications.cgi");
$sel->title_is("Classification Not Enabled");
logout($sel);
