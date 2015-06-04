#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

use Hypothesis::API;

use Term::ReadKey;

my $H;
my $test_uri = 'https://github.com/bbarker/Hypothesis-API/blob/master/xt/Testbed.md';

plan tests => 5;

sub init_h_0 {

    $H = Hypothesis::API->new;

    if ((q() ne $H->username) || (q() ne $H->password)) {
        fail("username or password not initialized correctly.");
    }
    pass("API object initialized.");
}


sub init_h_1 {

    print "Please enter your hypothes.is username:";
    chomp(my $username = <STDIN>);

    $H = Hypothesis::API->new($username);

    if (($username ne $H->username) || (q() ne $H->password)) {
        fail("username or password not initialized correctly.");
    }
    pass("API object initialized.");
}


sub init_h_2 {

    print "Please enter your hypothes.is username:";
    chomp(my $username = <STDIN>);
    print "Type your password:";
    ReadMode('noecho');
    chomp(my $password = <STDIN>);
    ReadMode(0);        # back to normal

    $H = Hypothesis::API->new($username, $password);

    if (($username ne $H->username) || ($password ne $H->password)) {
        fail("username or password not initialized correctly.");
    }
    pass("API object initialized.");
}
    
sub login {
    my $retval = $H->login;

    if ($retval != 0) {
        fail("login failed: non-zero exit status.")
    }    

    #FIXME: improve somehow?
    if (length "${\$H->token}" < 256) {
        fail("login failed: doesn't look like we got a token back.")
    }
    
    pass("login succeeded.");
}

sub create_simple {
    #Assumes already logged in.
    
    my $payload = {
        "uri"  => $test_uri,
        "text" => "testing create in hypothes.is API"
    };

    my $retval = $H->create($payload);
    
    if (length $retval < 4) {
        fail("create failed: didn't get an id.")
    } else {
        print "annotation id is: $retval\n";
    }
    pass("create succeeded.");
}


TODO: {
    init_h_0;
    undef $H;
    init_h_1;
    undef $H;
    init_h_2;
    login;
    create_simple;

}

