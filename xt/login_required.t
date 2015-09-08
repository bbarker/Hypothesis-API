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


plan tests => 10;

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
    if( $H->update_id($id, {'uri' => $new_url}) ) {
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


#
# Assumes already logged in.
#
# Note quite a unit test since we are testing
# infinite search AND retrieval of all results
# present before insertion. 
#
# Note also that this test depends on search_total in a 
# non-atomic way, so the account used for testing should
# not be creating or deleting annotations elsewhere.
#
#
sub search_infinite_and_insert {

    #TODO: Apparently search does NOT return the exact number of total
    #TODO: results as returned by search_total, which limits the original
    #TODO: design and accuracy of this test. Not only can we not check
    #TODO: for equality between total reported and actual returned, we
    #TODO: also can't check to see of items returned include new items
    #TODO: created (which we don't want), since we will always get this
    #TODO: if total reported is greater than what H gives us.

    my $create_and_get_id = sub {
        my $create_payload = {
            "uri"  => $test_uri,
            "text" => "testing create in hypothes.is API"
        };

        my $retval = $H->create($create_payload);

        if (length $retval < 4) {
            fail("create failed: didn't get an id.");
            return;
        }
        return $retval;
    };


    my $limit = 'Infinity';
    my $pg_size = 3;
    my $user = 'bbarker';
    my $result_iter  =       $H->search({limit => $limit, user => $user}, $pg_size);
    my $finite_limit = $H->search_total({limit => $limit, user => $user}, $pg_size);
    my $num_new = 8;
    my @top_items;
    my @temp_items;
    my $first = 1;
    while ( my $item = $result_iter->() ) {
        push @top_items, $item;
        if ($first) {
            $first = 0;
            print "Inserting new items\n";
            for (my $ii = 0; $ii < $num_new; $ii++) {
                my $new_id = $create_and_get_id->();
                push @temp_items, $new_id;
            }
        
        }
    }

    my $temp_finite_limit = $H->search_total({limit => $limit, user => $user}, $pg_size);
    if ($temp_finite_limit <= $finite_limit) {
        fail("Temporary additions didn't crease finite limit; check test parameters.");
        return;
    } else {
        print "$temp_finite_limit (temp) >= $finite_limit (orig)\n";
    }


    #Cleanup
    for (my $ii = 0; $ii < $num_new; $ii++) {
        if (not $H->delete_id($temp_items[$ii])) {
            fail("Unable to delete newly created annotation while authenticated!");
        } 
    }

    # FIXME: Apparently we can't expect equality from H:
    # if (@top_items != $finite_limit) {
    #     fail("Received $#top_items items instead of $finite_limit items.");
    #     return;
    # }
    if (@top_items > $finite_limit) {
        fail("Received more than $finite_limit items");
        return;
    }

    my @unique = do { my %seen; grep { !$seen{$_}++ }  @top_items };
    #my @unique = keys { map { $_ => 1 } @top_items }; # requres Perl 5.14+
    if (@top_items != @unique) {
        fail("Duplicate items returned: only $#unique/$finite_limit unique items.");
        return;
    } else {
        pass("Received $#unique unique equal to original limit of $finite_limit items.");
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
    search_infinite_and_insert;

}

