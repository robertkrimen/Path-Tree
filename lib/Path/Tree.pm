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

has root => qw/ is rw lazy_build 1 /;
sub _build_root {
    my $self = shift;
    return $self->build_node( tree => $self, rule => $self->build_rule( 'Always' ) );
}

has rule_parser => qw/ is ro lazy_build 1 /;
sub _build_rule_parser {
    my $self = shift;
    my $parser = Path::Tree::DataMapper->new;
    $parser->rule( 'Regexp' => sub { $self->build_rule( 'Regexp' => regexp => $_ ) } );
    return $parser;
}

sub parse_rule {
    my $self = shift;
    my $input = shift;
    return $self->rule_parser->map( $input )->result
}

has declare => qw/ is ro lazy_build 1 /;
sub _build_declare {
    my $self = shift;
    require Path::Tree::Declare;
    return Path::Tree::Declare->new( tree => $self );
}

sub rule {
    my $self = shift;
    return $self->rule_parser unless @_;
    return $self->declare->rule( @_ );
#    return $self->parse_rule( $_[0] ) if 1 == @_;
##    return $self->rule_parser->map( $_[0] )->result if 1 == @_;
#    return $self->build_rule( @_ );
}

sub node {
    my $self = shift;
    return $self->declare->dispatch( @_ );
#    die "Missing rule" unless @_;
#    if ( 1 == @_ ) {
#        my $rule = $self->rule( $_[0] );
#        return $self->build_node( rule => $rule );
#    }
#    return $self->build_node( @_ );
}

sub build_rule {
    my $self = shift;
    my $moniker = shift;
    die "Invalid rule arguments (@_)" if @_ % 2;
    return pkg->load_name( $self, 'Rule', $moniker )->new( @_ );
}

sub build_node {
    my $self = shift;
    my @moniker;
    push @moniker, shift if @_ % 2;
    return pkg->load_name( $self, 'Node', @moniker )->new( tree => $self, @_ );
}

sub dispatch {
    my $self = shift;
    my $path = shift;
    my $dispatch = $self->build_dispatch( path => $path );
    $self->root->dispatch( $dispatch );
    return $dispatch;
}

sub build_dispatch {
    my $self = shift;
    my @moniker;
    push @moniker, shift if @_ % 2;
    return pkg->load_name( $self, 'Dispatch', @moniker )->new( @_ );
}

1;
