package Path::Walker::Dispatcher;

use strict;
use warnings;

use Any::Moose;

use Path::Walker;

has root => qw/ is ro lazy_build 1 /;
sub _build_root {
    my $self = shift;
    return $self->build_route_with_rule( $self->build_rule( 'Always' ) );
}

sub rule {
    my $self = shift;
    return $self->parse_rule( @_ );
}

sub route {
    my $self = shift;
    return $self->build_route_with_rule( @_ );
}

sub plot {
    my $self = shift;
    $self->parse_plot( @_ );
}

sub dispatch {
    my $self = shift;
    my $path = shift;
    my %given = @_;

    my $walker;
    my @walker_arguments = ( path => $path, root => $self->root );
    if ( my $build_walker = $given{build_walker} ) {
        die "Do not know how to build walker with builder ($build_walker)"
            unless ref $build_walker eq 'CODE';
        $walker = $build_walker->( dispatcher => $self, @walker_arguments );
    }
    else {
        $walker = $self->build_walker( @walker_arguments );
    }
    
    if ( my $prepare_walker = $given{prepare_walker} ) {
        die "Do not know how to prepare walker with preparer ($prepare_walker)"
            unless ref $prepare_walker eq 'CODE';
        $prepare_walker->( $walker );
    }

    $walker->walk;
}

has class_namespace => qw/ is ro isa Str lazy_build 1 /;
sub _build_class_namespace {
    my $self = shift;
    return 'Path::Walker' if ref $self eq __PACKAGE__;
    return ref $self;
}

has rule_class => qw/ is rw isa HashRef /, default => sub { {} };

has route_class => qw/ is rw isa Str lazy_build 1 /;
sub _build_route_class { return shift->_class_for( 'Route' ) }

has walker_class => qw/ is rw isa Str lazy_build 1 /;
sub _build_walker_class { return shift->_class_for( 'Walker' ) }

has step_class => qw/ is rw isa Str lazy_build 1 /;
sub _build_step_class { return shift->_class_for( 'Step' ) }

sub _class_for {
    my $self = shift;
    my $moniker = shift;
    my $class = join '::', $self->class_namespace, $moniker;
#    eval "require $class" or die $@;
    return $class;
}

has visitor => qw/ is rw isa CodeRef|HashRef lazy_build 1 /;
sub _build_visitor { \&builtin_visitor }

sub builtin_visitor {
    my %given = @_;
    my $data = $given{data};
    
    if ( ref $data eq 'CODE' ) {
        return $data->();
    }
    else {
        die "Do not know how to visit data (", defined $data ? $data : 'undef', ")";
    }
}

sub visit {
    my $self = shift;
    my $visitor = shift;
    my %visit = @_;
    
    $visitor = $self->visitor unless defined $visitor;

    die "No visitor defined" unless defined $visitor;

    my $_visitor;
    if ( ref $visitor eq 'CODE' ) {
        $_visitor = $visitor;
    }
    elsif ( ref $visitor eq 'HASH' ) {
        my $data = $visit{data};
        $_visitor = $self->_find_CODE( $visitor, ref $data );
        $_visitor = $self->_find_CODE( $visitor, 'fallback' ) unless $_visitor;
        die "Did not find a visitor for (", ref $data, ")"
            unless $_visitor;
    }
    else {
        die "Do not know how to visit with visitor ($visitor)";
    }

    return $visitor->( %visit );
}

sub BUILD {
    my $self = shift;

    if ( ref ( my $parse_rule = $self->_parse_rule ) eq 'HASH' ) {
        $parse_rule->{Regexp} ||= sub { return $_[0]->build( Regexp => $_[1] ) };
    }
}

sub _find_CODE {
    my $self = shift;
    my $source = shift;
    my $input = shift;

    return unless defined $input;

    return $input if ref $input eq 'CODE';

    return $self->_find_CODE( $source, $source->{ $input } );
}

sub _parse {
    my $self = shift;
    my $parser = shift;
    my $interface = shift;
    my $input = shift;

    my $_parser;
    if ( ref $parser eq 'CODE' ) {
        $_parser = $_parser;
    }
    elsif ( ref $parser eq 'HASH' ) {
        $_parser = $self->_find_CODE( $parser, ref $input );
        $_parser = $self->_find_CODE( $parser, 'fallback' ) unless $_parser;
        die "Did not find a parser for (", ref $input, ")"
            unless $_parser;
    }
    else {
        die "Do not know how to parse with parser ($parser)";
    }

    return $_parser->( $interface, $input );
}

sub _parse_until {
    my $self = shift;
    my $parser = shift;
    my $interface = shift;
    my $condition = shift;
    my $input = shift;

    my $result = $input;
    # TODO Could be infinite loop
    while ( ! $condition->( $result ) ) {
        $result = $self->_parse( $parser, $interface, $result );
    }

    return $result;
}

sub parse_rule {
    my $self = shift;
    my $input = shift;

    # TODO Check for does
    $self->_parse_until(
        $self->_parse_rule,
        $self->parse_rule_interface,
        sub { blessed shift },
        $input,
    );
}

has parse_rule_interface => qw/ is ro lazy_build 1 /;
sub _build_parse_rule_interface {
    my $self = shift;
    return Path::Walker::Dispatcher::ParseRuleInterface->new( dispatcher => $self );
}

has parse_rule => qw/ accessor _parse_rule isa CodeRef|HashRef /, default => sub { {} };

sub parse_plot {
    my $self = shift;
    my $parent;
    $parent = ref $_[0] eq 'Path::Walker::Route' ? shift : $self->root;
    $self->_parse_plot->( $self->parse_plot_interface, $parent, @_ );
}

has parse_plot_interface => qw/ is ro lazy_build 1 /;
sub _build_parse_plot_interface {
    my $self = shift;
    return Path::Walker::Dispatcher::ParsePlotInterface->new( dispatcher => $self );
}

has parse_plot => qw/ accessor _parse_plot isa CodeRef lazy_build 1 /;
sub _build_parse_plot { return \&builtin_parse_plot }

sub builtin_parse_plot {
    my $parser = shift;
    my $parent = shift;

    my ( @children, $before, $after );
    while( @_ ) {

        if ( ref $_[0] eq '' ) { # Rule
    
            my $rule = shift;
            my $argument = shift;

            if ( $rule eq '-before' ) {
                $before = $argument;
                next;
            }
            elsif ( $rule eq '-after' ) {
                $after = $argument;
                next;
            }

            my $route = $parser->route( $rule );

            if ( ref $argument eq 'CODE' ) {
                $parser->( $route => $argument );
            }
            elsif ( ref $argument eq 'ARRAY' ) {
                $parser->( $route => @$argument );
            }
            else {
                die "Do not know how to parse argument ($argument)";
            }

            push @children, $route;
        }
        else {
            push @children, shift;
        }
    }

    $parent->add( @children );
    $parent->before( $before ) if $before;
    $parent->after( $after ) if $after;
}

sub build_rule {
    my $self = shift;
    my $kind = shift;
    my $rule_class = $self->rule_class->{$kind} ||= $self->_class_for( "Rule::$kind" );
    return $rule_class->new( @_ );
}

sub build_route_with_rule {
    my $self = shift;
    my $rule = shift;
    return $self->build_route( rule => $self->parse_rule( $rule ), @_ );
}

sub build_route {
    my $self = shift;
    return $self->route_class->new( @_ );
}

sub build_walker {
    my $self = shift;
    return $self->walker_class->new( dispatcher => $self, @_ );
}

sub build_step {
    my $self = shift;
    return $self->step_class->new( @_ );
}

package Path::Walker::Dispatcher::ParseRuleInterface;

use Any::Moose;

use overload
    '&{}' => sub { my $this = shift; return sub { $this->parse( @_ ) } };
;

has dispatcher => qw/ is ro required 1 /;

sub parse {
    my $self = shift;
    return $self->dispatcher->parse_rule( @_ );
}

sub build {
    my $self = shift;
    return $self->dispatcher->build_rule( @_ );
}

package Path::Walker::Dispatcher::ParsePlotInterface;

use Any::Moose;

use overload
    '&{}' => sub { my $this = shift; return sub { $this->parse( @_ ) } };
;

has dispatcher => qw/ is ro required 1 /,
    handles => [qw/ build_route build_route_with_rule /];

sub parse {
    my $self = shift;
    return $self->dispatcher->parse_plot( @_ );
}

sub rule {
    my $self = shift;
    return $self->dispatcher->parse_rule( @_ );
}

sub route {
    my $self = shift;
    return $self->dispatcher->build_route_with_rule( @_ );
}

1;
