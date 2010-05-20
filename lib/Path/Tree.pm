package Path::Tree;
# ABSTRACT: Tree-ish path dispatching

use strict;
use warnings;

use Any::Moose;

use Path::Tree::Rule;
use Path::Tree::Node;
use Path::Tree::Dispatch;
use Path::Tree::DataMapper;

use Package::Pkg;

has root => qw/ is rw /;

has rule_parser => qw/ reader rule_parser lazy_build 1 /;
sub _build_rule_parser {
    my $self = shift;
    my $parser = Path::Tree::DataMapper->new;
    $parser->rule( 'Regexp' => sub { $self->build_rule( 'Regexp' => regexp => $_ ) } );
    return $parser;
}

sub parse_rule {
    my $self = shift;
    return $self->rule_parser unless @_;
    $self->rule_parser->map( @_ )->result;
}

sub build_rule {
    my $self = shift;
    my $moniker = shift;
    return pkg->load_name( $self, 'Rule', $moniker )->new( @_ );
}

1;
