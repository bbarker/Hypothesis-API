#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

use Hypothesis::API;

use Term::ReadKey;

my $H;
my $test_uri = 'https://github.com/bbarker/Hypothesis-API/blob/master/xt/Testbed.md';
my $test_uri2 = 'https://github.com/bbarker/Hypothesis-API/blob/master/xt/Testbed2.md';

#
# 0 = None, 5 = Max:
my $VERB = 5; 


plan tests => 9;

sub init_h_0 {

    $H = Hypothesis::API->new;

    if ((defined $H->username) || (defined $H->password)) {
        fail("username or password not initialized correctly.");
        return;
    }
    pass("API object initialized.");
}


sub init_h_1 {

    print "Please enter your hypothes.is username:";
    chomp(my $username = <STDIN>);

    $H = Hypothesis::API->new($username);

    if (($username ne $H->username) || (defined $H->password)) {
        fail("username or password not initialized correctly.");
        return;
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
        return;
    }
    pass("API object initialized.");
}
    
sub login {
    my $retval = $H->login;

    if ($retval != 0) {
        fail("login failed: non-zero exit status.");
        return;
    }    

    #FIXME: improve somehow?
    if (length "${\$H->token}" < 256) {
        fail("login failed: doesn't look like we got a token back.");
        return;
    }
    
    pass("login succeeded.");
}

#
# Assumes already logged in.
#
sub create_simple {
    
    my $payload = {
        "uri"  => $test_uri,
        "text" => "testing create in hypothes.is API"
    };

    my $retval = $H->create($payload);
    
    if (length $retval < 4) {
        fail("create failed: didn't get an id.");
        return;
    } else {
        print "annotation id is: $retval\n";
    }
    pass("create succeeded.");
    return $retval;
}


#
# Assumes already logged in.
#
sub update_url {
    my ($id, $new_url) = @_;

    if ($VERB > 2) {
        warn "Waiting 10 seconds to allow checking the webpages:\n" .
	     "$test_uri -> $new_url."; 
        sleep(10);
    }
    if( $H->update_id($id, {url => $new_url}) ) {
        pass("Update of annotation successful.");
    } else {
        fail("Unable to update newly created annotation while authenticated!");
    }
}


sub delete_unauth {
    my ($id) = @_;

    my $Htmp = Hypothesis::API->new;
    if( $Htmp->delete_id($id) ) {
        fail("Shouldn't be able to delete without authenticating!");
    } else {
        pass("Delete without authentication unsuccessful.");
    }
}

#
# Assumes already logged in.
#
sub delete_simple {
    my ($id) = @_;

    if ($VERB > 2) {
        warn "Waiting 10 seconds to allow checking the webpage.";
        sleep(10);
    }
    if( $H->delete_id($id) ) {
        pass("Deletion of newly created annotation successful.");
    } else {
        fail("Unable to delete newly created annotation while authenticated!");
    }
}

#
# At the time of writing, behavior not specified by API.
#
sub delete_invalid_id {
    my ($id) = @_;

    if( $H->delete_id($id . "___xyz123___") ) {
        fail("Is returning true if attempting to delete an invalid id.");
    } else {
        pass("Is returning false if attempting to delete an invalid id.");
    }
}




TODO: {
    init_h_0;
    undef $H;

    init_h_1;
    undef $H;

    init_h_2;
    login;
    my $test_id = create_simple;
    update_url($test_id, $test_uri2);
    delete_unauth($test_id);
    delete_simple($test_id);
    delete_invalid_id($test_id);

}

