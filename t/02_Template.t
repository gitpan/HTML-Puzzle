# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..7\n"; }
END {print "not ok " . ++$testid . "\n" unless $loaded;}

use DBI;
use HTML::Puzzle::Template;
use Data::Dumper;


# Create test obj
my $comp		= new HTML::Puzzle::Template(		
											filename => 'templates/simple.tmpl'
						);
# Standard HTML::Template use
$comp->param('test' => "It works!!!");
$_ = $comp->output;
print;

if (m/It works/ && !m/placeholder/) {
	print "\nok " . ++$testid . "\n";
} else {
    exit;
}

# Advanced output method use
$_ = $comp->output(as => {'test' => "It works!!!"});
print;

if (m/It works/ && !m/placeholder/) {
	print "\nok " . ++$testid . "\n";
} else {
    exit;
}

# check vanguard mode
$_ = $comp->html({'test' => "It works!!!"},'templates/simple_vanguard.tmpl');
print;

if (m/It works/ && m/vanguard/) {
	print "\nok " . ++$testid . "\n";
} else {
    exit;
}

# html method use and replacing filename
$_ = $comp->html({'test' => "It works!!!"},'templates/simple_html.tmpl');
print;

if (m/It works/ && !m/placeholder/ && m/\<HTML\>/) {
	print "\nok " . ++$testid . "\n";
} else {
    exit;
}

# ...again to check caching
$_ = $comp->html({'test' => "It works!!!"},'templates/simple_html.tmpl');
print;

if (m/It works/ && !m/placeholder/ && m/\<HTML\>/) {
	print "\nok " . ++$testid . "\n";
} else {
    exit;
}

# ...check autoDeleteHeader
$comp->autoDeleteHeader(1);
$_ = $comp->html({'test' => "It works!!!"},'templates/simple_html.tmpl');
print;
print $comp->header;

if (m/It works/ && !m/placeholder/ && !m/\<HTML\>/ && $comp->header=~m/\<HTML\>/) {
	print "\nok " . ++$testid . "\n";
} else {
    exit;
}

# check js_header
$comp->autoDeleteHeader(1);
$_ = $comp->html({'test' => "It works!!!"},'templates/html_js.tmpl');
print;
$_ = $comp->js_header;
print;

if (m/doNothing/) {
	print "\nok " . ++$testid . "\n";
} else {
    exit;
}

$loaded = 1;

1;
