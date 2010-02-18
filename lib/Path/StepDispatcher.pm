package Path::StepDispatcher;

use strict;
use warnings;

use Any::Moose;

package Path::StepDispatcher::Match;

use Any::Moose;

has remaining_path => qw/ is ro required 1 isa Str /;
has matching_path => qw/ is ro required 1 isa Str /;
has matching_arguments => qw/ is ro required 1 isa ArrayRef /, default => sub { [] };

package Path::StepDispatcher::Rule::Regexp;

use Any::Moose;

has regexp => qw/ is ro required 1 isa Regexp /;

sub match {
    my $self = shift;
    my $path = shift;

    return unless my @arguments = ( $path =~ $self->regexp );
    my $remaining_path = eval q{$'};

    undef @arguments unless defined $1; # Just got the success indicator

    return Path::StepDispatcher::Match->new(
        remaining_path => $remaining_path,
        matching_path => '',
        matching_arguments => \@arguments,
    );
}

package Path::StepDispatcher::Switch;

use Any::Moose;

has rule => qw/ is ro /;
has sequence => qw/ is ro required 1 isa ArrayRef /, default => sub { [] };

sub add {
    my $self = shift;
    my $node = shift;

    push @{ $self->sequence }, $node;

    return $node;
}

sub dispatch {
    my $self = shift;
    my $ctx = shift;

    my $starting_path = my $remaining_path = $ctx->path;

    my $match;
    if ( my $rule = $self->rule ) {
        return unless $match = $rule->match( $remaining_path );
        $remaining_path = $match->remaining_path;
    }
    $ctx->starting_path( $starting_path );
    $ctx->remaining_path( $remaining_path );
    $ctx->path( $remaining_path );

    for my $node (@{ $self->sequence }) {
        $node->dispatch( $ctx );
    }

    $ctx->starting_path( undef );
    $ctx->remaining_path( undef );
}

package Path::StepDispatcher::Item;

use Any::Moose;

has data => qw/ is ro /;

sub dispatch {
    my $self = shift;
    my $ctx = shift;

    $ctx->visit( $self->data, $self );
}

use Any::Moose;

package Path::StepDispatcher::Context;

use Any::Moose;

has path => qw/ is rw isa Str /;
has starting_path => qw/ is rw isa Maybe[Str] /;
has remaining_path => qw/ is rw isa Maybe[Str] /;

has visitor => qw/ is ro required 1 isa CodeRef /; 

sub visit {
    my ( $self, $data, $item ) = @_;
    $self->visitor->( $self, $data, $item );
}

package Path::StepDispatcher::Builder;

use Any::Moose;
use Path::StepDispatcher::Carp;

has $_ => ( accessor => "_$_" )
    for qw/ parse_rule parse_item build_context build_switch /;

sub parse_rule {
    my $self = shift;
    my $input = shift;

    my $rule;

    $rule = $self->_parse( $self->_parse_rule, $input );
    return $rule if defined $rule; # TODO Check if $rule does Rule

    $rule = $self->builtin_parse_rule( $input );
    return $rule if defined $rule; # TODO Check if $rule does Rule

    croak "Unable to parse rule ($input)";
}

sub builtin_parse_rule {
    my $self = shift;
    my $input = shift;

    if ( ref $input eq 'Regexp' ) {
        return Path::StepDispatcher::Rule::Regexp->new( regexp => $input );
    }

    return undef;
}

sub parse_item {
    my $self = shift;
    return $self->_parse( $self->_parse_item, @_ );
}

sub build_context {
    my $self = shift;
    return $self->_build( $self->_build_context, @_ );
}

sub build_switch {
    my $self = shift;
    return $self->_build( $self->_build_switch, @_ );
}

sub _parse {
    my $self = shift;
    my $parser = shift;

    if ( ref $parser eq 'CODE' ) {
        return $parser->( @_ );
    }
    else {
        croak "Do not know how to parse with ($parser)";
    }
}

sub _build {
    my $self = shift;
    my $builder = shift;

    if ( ref $builder eq 'CODE' ) {
        return $builder->( @_ );
    }
    elsif ( $builder && ref $builder eq '' ) {
        $builder->new( @_ ); # TODO Wrap this?
    }
    else {
        croak "Do not know how to builder with ($builder)";
    }
}

1;
