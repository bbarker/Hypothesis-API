#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

use Hypothesis::API;

my $H;
my $test_uri = 'https://github.com/bbarker/Hypothesis-API/blob/master/xt/Testbed.md';
my $rand_user;
my $rand_id;

plan tests => 10;

sub init_h_0 {

    $H = Hypothesis::API->new;

    if ((defined $H->username) || (defined $H->password)) {
        fail("username or password not initialized correctly.");
        return;
    }
    pass("API object initialized.");
}

sub test_url_encode_0 {

    my $spacey_url = "http://perl.com/foo bar";
    my $url_enc1 = $H->uri_encoder->encode($spacey_url);
    my $url_enc2 = $H->uri_encoder->encode($url_enc1);
    if ($url_enc1 ne $url_enc2) {
        fail("url encoder is double-encoding.");
        return;
    }
    pass("url encoder didn't double encode");

}

sub search_recent {

    $H->set_ua_timeout(10);
    
    my $result_iter = $H->search;
    my @top_items;
    while ( my $item = $result_iter->() ) {
        push @top_items, $item;
    }
    if (@top_items > 0 ) {
        my $rand_idx = int(rand(@top_items));
        if (defined $top_items[$rand_idx]->{'user'}) {
            $rand_id   = $top_items[$rand_idx]->{'id'};
            $rand_user = $top_items[$rand_idx]->{'user'};
            pass("Got a recent user and annotation id.");
        } else {
            fail("User element not defined!");
        }
    } else {
        fail("Didn't get any result results!");
    }
}


sub search_total {

    $H->set_ua_timeout(10);

    my $total = $H->search_total;
    if ($total > 0 ) {
        pass("Reported $total total items.");
    } else {
        fail("User element not defined!");
    }
}


sub search_page_with_one {

    $H->set_ua_timeout(10);

    my $limit = 10;
    #
    # Assumption: this page has only one annotation.
    #
    my $uri = "https://github.com/bbarker/Hypothesis-API/blob/"
              . "master/xt/TestOnlyOne.md";

    my $result_iter = $H->search({
        limit => $limit,
        uri   => $uri,
    });
    my @top_items;
    while ( my $item = $result_iter->() ) {
        push @top_items, $item;
    }
    if (@top_items != 1) {
        fail("Expected to see exactly one annotation of this page.");
    } else {
        pass("Saw @{[$#top_items+1]} annotations of TestOnlyOne.md.");
    }
}



sub search_30 {

    $H->set_ua_timeout(10);

    my $limit = 30;
    my $result_iter = $H->search({limit => $limit});
    my @top_items;
    while ( my $item = $result_iter->() ) {
        push @top_items, $item;
    }
    if (@top_items != $limit) {
        fail("Received @{[$#top_items+1]} items instead of $limit items.");
    } else {
        pass("Received $limit items.");
    }
}


sub search_30_by_5incs {

    $H->set_ua_timeout(10);

    my $limit = 30;
    my $pg_size = 5;
    my $result_iter = $H->search({limit => $limit}, $pg_size);
    my @top_items;
    while ( my $item = $result_iter->() ) {
        push @top_items, $item;
    }
    if (@top_items != $limit) {
        fail("Received @{[$#top_items+1]} items instead of $limit items.");
    } else {
        my @unique = do { my %seen; grep { !$seen{$_}++ }  @top_items };
        #my @unique = keys { map { $_ => 1 } @top_items }; # requres Perl 5.14+
        if (@top_items != @unique) {
            fail("Duplicate items returned: only @{[$#unique+1]}"
                ."/$limit unique items.");
        } else {
            pass("Received $limit items.");
        }
    }
}


sub search_google_com {

    $H->set_ua_timeout(10);

    my $limit = 10;
    my $uri = 'https://www.google.com/?gws_rd=ssl';
    my $result_iter = $H->search({
        limit => $limit,
        uri   => $uri,
    });
    my @top_items;
    while ( my $item = $result_iter->() ) {
        push @top_items, $item;
    }
    if (@top_items < 2) {
        fail("Expected to see more than 2 annotations of google.com.");
    } else {
        pass("Saw @{[$#top_items+1]} annotations of google.com.");
    }
}

#
# TODO: test quote & text parameters to search query
#



sub read_empty {

    $H->set_ua_timeout(10);

    my $item = $H->read_id;
    if (defined $item->{'id'}) {
        pass("Got a single item from read.");
    } else {
        fail("Didn't see an id in object returned from read.");
    }   
}

sub read_id_test {

    $H->set_ua_timeout(10);

    my $item = $H->read_id($rand_id);
    if (defined $item->{'id'}) {
        if (($item->{'id'} eq $rand_id) and ($rand_id ne '')) {
            pass("Got back item with id ${\$item->{'id'}} from read.");
        } else {
            fail("Got wrong id back from read");
        }
    } else {
        fail("Didn't see an id in object returned from read.");
    }   
}


TODO: {
    init_h_0;
    test_url_encode_0;
    search_recent;
    search_total;
    search_page_with_one;
    search_30;
    search_30_by_5incs;
    search_google_com;
    read_empty;
    read_id_test;
}

