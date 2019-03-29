package Time::Tracker::Controller::Health;
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';
use strictures;
sub welcome{
    my $c = shift->openapi->valid_input or return;
    $c->render( openapi => { } );
}

1;
