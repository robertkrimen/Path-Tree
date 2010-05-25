package Path::Tree::DataMap;

use Any::Moose;

has rulelist => qw/ is ro lazy_build 1 isa ArrayRef /;
sub _build_rulelist { [] };

has value_cache => qw/ is ro lazy_build 1 isa HashRef clearer clear_value_cache /;
sub _build_value_cache { {} }

has type_cache => qw/ is ro lazy_build 1 isa HashRef clearer clear_type_cache /;
sub _build_type_cache { {} }

has fallback => qw/ is rw isa CodeRef|Path::Tree::DataMap /;

sub map {
    my $self = shift;
    my $input = shift;

    my $type = ref $input;
    if ( $type eq '' ) {
        return $self->value_cache->{$input} if exists $self->value_cache->{$input};
    }
    else {
        return $self->type_cache->{$type} if exists $self->type_cache->{$type};
    }

    my @rulelist = @{ $self->rulelist };
    my @result;
    for my $rule (@rulelist) {

        if ( $rule->matcher ) { next unless $rule->match( $input ) }

        next unless @result = $rule->map( $input );

        if ( $rule->static_map && $rule->matcher ) {
            if ( $rule->match_input_type ) {
                $self->type_cache->{$type} = $result[0];
            }
            elsif ( ref $rule->matcher eq '' ) {
                $self->value_cache->{$input} = $result[0];
            }
        }

        last if 1;
    }

    unless ( @result ) {
        if ( my $fallback = $self->fallback ) {
            if ( ref $fallback eq 'CODE' ) {
                local $_ = $input;
                @result = $fallback->( $_ );
            }
            else {
                @result =  $fallback->map( $input );
            }
        }
    }

    return unless @result;
    return $result[0];
}

#has match_input_type => qw/ is ro /;
#has matcher => qw/ is ro isa Maybe[CodeRef] /;
#has matcher_type => qw/ is ro lazy_build 1 /;
#sub _build_matcher_type { return ref shift->matcher }

#has static_map => qw/ is ro /;
#has value => qw/ is ro required 1 /;
sub rule {
    my $self = shift;

    my @arguments;
    if ( @_ == 1 && ref $_[0] eq 'CODE' ) {
        push @arguments, value => shift;
    }
    else {
        die "Invalid arguments # (@{[ scalar @_ ]})" unless 3 <= @_ and @_ <= 4;

        my ( $i0 );
        $i0 = shift;
        if      ( $i0 eq 'type' )   { push @arguments, match_input_type => 1 }
        elsif   ( $i0 eq 'value' )  {}
        else                        { die "Invalid matcher ($i0)" }
        push @arguments, matcher => shift;

        if ( @_ == 1 ) {
            $i0 = shift;
            push @arguments, static_map => 1 unless ref $i0 eq 'CODE';
            push @arguments, value => $i0;
        }
        else {
            $i0 = shift;
            if      ( $i0 eq 'value' )  { push @arguments, static_map => 1 }
            elsif   ( $i0 eq 'map' )    {}
            else                        { die "Invalid mapper ($i0)" }
            push @arguments, value => shift;
        }
    }

    my $rule = Path::Tree::DataMap::Rule->new( @arguments );
    push @{ $self->rulelist }, $rule;
    return $self;
    
#    my ( $matcher, $mapper );
#    $matcher = shift if @_ > 1;
#    $mapper = shift;

#    die "Missing mapper" unless $mapper;
#    die "Invalid mapper ($mapper)" unless ref $mapper eq 'CODE';

#    my @arguments;
#    if ( $matcher ) {
#        my $matcher_;
#        if      ( ref $matcher eq 'CODE' )      {}
#        elsif   ( ref $matcher eq 'Regexp' )    { $matcher_ = sub { $_ =~ $matcher } }
#        elsif   ( ref $matcher eq '' &&
#                  $matcher =~ m/^(?:CODE|HASH|ARRAY|SCALAR|Regexp)$/x )
#                                                { $matcher_ = sub { ref $_ eq $matcher } }
#        else                                    { die "Invalid matcher ($matcher)" }
#        $matcher_ ||= $matcher;
#        push @arguments, matcher => $matcher_;
#    }

#    my $rule = Path::Tree::DataMap::Rule->new( mapper => $mapper, @arguments );
#    push @{ $self->rulelist }, $rule;
}

package Path::Tree::DataMap::Map;

use Any::Moose;

has mapper => qw/ is ro required 1 isa Path::Tree::DataMap /;
has input => qw/ is ro required 1 /;
has result => qw/ accessor _result predicate success /;
has error => qw/ is rw predicate failure /;

sub result {
    my $self = shift;
    return $self->_result( shift ) if @_;
    die "Missing result" unless $self->success;
    return $self->_result;
}

sub map {
    my $self = shift;
    my $input = shift;
    my $map = $self->mapper->map( $input );
    $self->map( $map );
}

sub done { $_[0]->success || $_[0]->failure }

package Path::Tree::DataMap::Rule;

use Any::Moose;

has match_input_type => qw/ is ro /;
has matcher => qw/ is ro /;
has matcher_type => qw/ is ro lazy_build 1 /;
sub _build_matcher_type { return ref shift->matcher }

has static_map => qw/ is ro /;
has value => qw/ is ro required 1 /;

sub match {
    my $self = shift;
    my $input = shift;
    
    my $matcher = $self->matcher;
    my $matcher_type = $self->matcher_type;
    if      ( $self->match_input_type )     { return ref $input eq $matcher }
    elsif   ( $matcher_type eq 'Regexp' )   { return $input =~ $matcher } 
    elsif   ( $matcher_type eq '' )         { return $input eq '' }
    elsif   ( $matcher_type eq 'CODE' )     { local $_ = $input; return $matcher->( $input ) }
    else                                    { die "Invalid matcher ($matcher) ($matcher_type)" }
}

sub map {
    my $self = shift;
    my $input = shift;

    my $value = $self->value;
    if ( $self->static_map ) {
        return $value;
    }
    else {

        die "Invalid mapper ($value)" unless ref $value eq 'CODE';

        local $_ = $input;
        return $value->( $input );
    }
}

1;
