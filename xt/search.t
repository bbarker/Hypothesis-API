#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

use Hypothesis::API;

use Term::ReadKey;

my $H;
my $test_uri = 'https://github.com/bbarker/Hypothesis-API/blob/master/xt/Testbed.md';

plan tests => 3;

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

sub search_tmp {

    my $query = {uri => $test_uri};
    $H->search($query);
    pass("not a real test");

}




TODO: {
    init_h_0;
    test_url_encode_0;
    search_tmp;

}

