package Contentity::Database::Results;

use Contentity::Class
    version   => 0.02,
    debug     => 0,
    import    => 'class',
    base      => 'Contentity::Base',
    utils     => 'self_params blessed split_to_list tprintf ucwords extend truelike',
    constants => 'ARRAY HASH',
    mutators  => 'pages_before pages_after',
    accessors => 'table ident rows query params args
                  size total limit offset
                  page_no page_size last_page
                  more less all from to',
    alias     => {
        page => 'page_no',
    },
    constant => {
        REVERSE_ORDER_FORMAT => "%s_reverse",
        ORDER_BY_FORMAT      => "Order by %s",
        STATIC_COLUMN_CLASS  => "static",
        ORDER_PARAMETER      => 'order',
        ORDER_CSS_CLASS      => 'order',
        ORDERING_CSS_CLASS   => 'ordering',
        # Yes, this IS correct.  Rows returned in ascending order are
        # displayed going down the page, descending order has them going
        # up
        ASCENDING_CSS_CLASS  => 'down',
        DESCENDING_CSS_CLASS => 'up',
    };

use Badger::Debug 'debug_caller';

our @DATA_ARGS = qw(
    rows size total limit offset
    page_no page_size last_page
    more less none one all from to
);

our @DISPLAY_ARGS = qw(
    pages_before pages_after
    start_page end_page page_range
);

sub init {
    my ($self, $config) = @_;

    # Use the table reference to access the workspace to fetch default config
    my $table    = $config->{ table };
    my $defaults = $table
                 ? $table->workspace->config('search_results')
                 : { };

    # merge default and config into a single hash
    $config = extend({ }, $defaults, $config);

    # copy everything in $config into $self
    @$self{ keys %$config } = values %$config;

#   my $records = $self->{ records } ||= [ ];    #  TODO
    my $rows    = $self->{ rows    } ||= [ ];
    my $size    = $self->{ size    } ||= scalar @$rows;
    my $total   = $self->{ total   } ||= $size;
    my $limit   = $self->{ limit   } ||= $size;
    my $offset  = $self->{ offset  } ||= 0;
    my $last    = $offset + $limit;
    my $limdiv  = $limit || 1;          # avoid division by zero
    $last       = $total if $last > $total;

    $self->{ page_no   } = int($offset / $limdiv) + 1;
    $self->{ page_size } = $limit;
    $self->{ last_page } = int($total / $limdiv) + ($total % $limdiv ? 1 : 0);
    $self->{ last_page } = 1 if $self->{ last_page } == 0;
    $self->{ more      } = ($last < $total           ) ? 1 : 0;
    $self->{ less      } = ($offset > 0              ) ? 1 : 0;
    $self->{ none      } = ($total == 0              ) ? 1 : 0;
    $self->{ one       } = ($total == 1              ) ? 1 : 0;
    $self->{ all       } = ($total && $total == $size) ? 1 : 0;
    # watch out for fence-post errors.  limit:10, offset:0 is records
    # from 1 (offset + 1) to 10 (offset + limit)
    $self->{ from      } = $total ? $offset + 1 : 0;
    $self->{ to        } = $last;

    # default display options
    $self->{ pages_before } ||= 2;
    $self->{ pages_after  } ||= 2;

    # expand are the button items that need expand via TT
    $self->{ expand } = split_to_list( $config->{ expand } );

    return $self;
}


sub page_range {
    my ($self, $params) = self_params(@_);
    my $before = $params->{ before } || $self->{ pages_before };
    my $after  = $params->{ after  } || $self->{ pages_after  };
    my $expect = $before + $after + 1;
    my ($start, $end);

    $start = $self->{ page_no } - $before;
    $start = 1 if $start < 1;
    $end   = $start + $before + $after;
    $end   = $self->{ last_page } if $end > $self->{ last_page };

    # if we've hit the end page and have less than N pages to show then we
    # can move the start back a bit, e.g. 1 2 3 [4] 5 can show more than 2
    # pages before
    my $width = $end - $start + 1;

    if ($width < $expect) {
        my $adjust = $expect - $width;
        $adjust = $start - 1 if $adjust >= $start;
        $start -= $adjust;
    }

    $self->{ page_range } = [$start, $end];
    $self->{ start_page } = $start;
    $self->{ end_page   } = $end;
}


sub start_page {
    my $self = shift;
    $self->page_range(@_) unless $self->{ page_range };
    return $self->{ start_page };
}


sub end_page {
    my $self = shift;
    $self->page_range(@_) unless $self->{ page_range };
    return $self->{ end_page };
}


sub table_records {
    my $self  = shift;
    my $table = $self->{ table }
        || return $self->error_msg( missing => 'table' );
    return $table->records( $self->{ rows } );
}


sub records {
    my $self = shift;
    return $self->{ records }
       ||= $self->table_records;
}


sub buttons {
    my $self  = shift;
    return $self->{ buttons }
        ||= $self->paging_buttons(@_);
}

sub paging_buttons {
    my ($self, $params) = self_params(@_);
    my $start  = $self->start_page;
    my $end    = $self->end_page;
    my $width  = $end - $start;
    my $psize  = $self->{ page_size };
    my (@buttons, $button);

    # if we're not on the first page then we can go back to the first page
    if ($self->{ less }) {
        my $prev_from = $self->{ from } - $psize;
        my $prev_to   = $self->{ from } - 1;
        my $prev_p    = $self->{ page_no } - 1;
        push(@buttons, $button)
            if $button = $self->button(
                first_page => {
                    from_item => 1,
                    to_item   => $psize,
                    page_no   => 1,
                    params    => { page_no => 1 },
                }
            );

        push(@buttons, $button)
            if $button = $self->button(
                previous_page => {
                    prev      => 1,
                    from_item => $prev_from,
                    to_item   => $prev_to,
                    page_no   => $prev_p,
                    text      => $prev_p,
                    params    => { page_no => $prev_p },
                }
            );
    }

    foreach my $p ($start..$end) {
        my $page_from = ($p - 1) * $psize + 1;
        my $page_to   = $page_from + $psize - 1;
        my $warm      = $p == $self->{ page_no };
        $page_to = $self->{ total } if $page_to > $self->{ total };

        push(@buttons, $button)
            if $button = $self->button(
                page_no => {
                    page_no   => $p,
                    from_item => $page_from,
                    to_item   => $page_to,
                    text      => $p,
                    warm      => $warm,
                    params    => { page_no => $p },
                }
            );
    }

    # if we're not on the last page then we can go forward
    if ($self->{ more }) {
        my $next_from = $self->{ from    } + $psize;
        my $next_to   = $self->{ to      } + $psize;
        my $next_page = $self->{ page_no } + 1;
        my $last_page = $self->{ last_page };
        my $last_from = $last_page * $psize + 1;
        my $last_to   = $self->{ total };
        $next_to = $self->{ total } if $next_to > $self->{ total };
        push(@buttons, $button)
            if $button = $self->button(
                next_page => {
                    next      => 1,
                    from_item => $next_from,
                    to_item   => $next_to,
                    text      => $next_page,
                    page_no   => $next_page,
                    params    => { page_no => $next_page },
                }
            );
        push(@buttons, $button)
            if $button = $self->button(
                last_page => {
                    from_item => $last_from,
                    to_item   => $last_to,
                    text      => $last_page,
                    page_no   => $last_page,
                    params    => { page_no => $last_page },
                }
            );
    }

    $self->debug_data( buttons => \@buttons ) if DEBUG;

    return \@buttons;
}

sub button {
    my ($self, $name, $spec) = @_;
    my $buttons = $self->{ button_types };
    my $config  = extend(
        { },
        $buttons->{ $name },
        $spec
    );

    # The 'active' option must be set to a true value.  This allows
    # workspaces (e.g. site, portfolios, etc) to redefine their own set
    # of buttons that they do/won't want.
    return undef
        unless truelike $config->{ active };

    # The 'expand' option specifies those items that contain
    # template fragments that we must expand via tprintf()
    foreach my $item (@{ $self->{ expand } }) {
        my $template = $config->{ $item } || next;
        $config->{ $item } = tprintf($template, $config);
    }

    return $config;
}


sub params_used {
    my $self   = shift;
    my $params = $self->{ params };
    return $self->{ params_used } ||= {
        map  { @$_ }
        grep { defined $_->[1] && length $_->[1] }
        map  { [$_, $params->{ $_ }]  }
        keys %$params
    };
}


sub columns {
    my $self = shift;
    return @_
        ? $self->set_columns(@_)
        : $self->{ columns };
}

sub set_columns {
    my $self  = shift;
    my $cols  = @_ == 1 ? split_to_list(shift) : [ @_ ];
    my $sane  = $self->{ columns } = [ ];
    my $order = $self->params->{ order };

    # Most of the time a simple list of columns will suffice, e.g.
    # ['town', 'availability', 'postcode']. From that we can extract
    # the relevant data item from the row data and print a column heading
    # with a capital letter.  Some times we want a different heading,
    # e.g. "Location" instead of "Town".  Some fucking numpty (me)
    # thought it would be a good idea to allow a two element list,
    # e.g. [['town', 'Location'], 'availability', 'postcode'].  Then
    # that wasn't enough, so the moron added more positional arguments
    # (I'm not going to even pretend I can remember what order they go
    # in).  At some point Mr Fuckwit saw sense and added support for a
    # hash array but it was too late because the array form was already
    # being used in a dozen different places.  So here we are now.
    # Writing a method to take any of those various column specifications
    # and turn it into something sane.

    my $ord_css  = $self->ORDERING_CSS_CLASS;
    my $asc_css  = $self->ASCENDING_CSS_CLASS;
    my $desc_css = $self->DESCENDING_CSS_CLASS;

    for my $column (@$cols) {
        my ($spec, $name);
        my (@head_classes, @body_classes);

        if (ref $column eq HASH) {
            $spec = $column;
        }
        elsif (ref $column eq ARRAY) {
            my ($name, $title, $class, $span) = @$column;
            $spec = {
                name    => $name,
                title   => $title,
                colspan => $span,
                class   => $class,
            };
        }
        else {
            $spec = {
                name => $column
            };
        }

        $name = $spec->{ name };

        if ($spec->{ class }) {
            push(@head_classes, $spec->{ class });
            push(@body_classes, $spec->{ class });
        }

        if ($name) {
            $spec->{ title   } ||= ucwords( $name );
            $spec->{ order   } ||= $name;
            $spec->{ reverse } ||= sprintf($self->REVERSE_ORDER_FORMAT, $spec->{ order });
            $spec->{ tooltip } ||= sprintf($self->ORDER_BY_FORMAT, $spec->{ order });
        }
        else {
            $spec->{ static } = 1;
            $spec->{ class  } ||= $self->STATIC_COLUMN_CLASS;
            push(@head_classes, $self->STATIC_COLUMN_CLASS);
        }

        # support shorter name for 'colspan'
        $spec->{ colspan } ||= $spec->{ span };

        push(@head_classes, $spec->{ head_class})
            if $spec->{ head_class };

        push(@body_classes, $spec->{ body_class})
            if $spec->{ body_class };


        if ($spec->{ order }) {
            push(@head_classes, $self->ORDER_CSS_CLASS);
            push(@body_classes, $self->ORDER_CSS_CLASS);
            $spec->{ set_order } = $spec->{ order };

            # see if the order parameter matches either of these
            if ($order) {
                $self->debug("comparing order parameter [$order] to spec: [$spec->{order}]") if DEBUG;

                if ($order eq $spec->{ order }) {
                    push(@head_classes, $ord_css, $asc_css);
                    push(@body_classes, $ord_css, $asc_css);
                    $spec->{ set_order } = $spec->{ reverse };
                    $spec->{ ordering } = "$ord_css $asc_css";
                }
                elsif ($order eq $spec->{ reverse }) {
                    push(@head_classes, $ord_css, $desc_css);
                    push(@body_classes, $ord_css, $desc_css);
                    $spec->{ set_order } = $spec->{ order };
                    $spec->{ ordering } = "$ord_css $desc_css";
                }
            }
        }

        # Set head_classes and body_classes to contain our computed classes
        # but don't override any explciti head_class or body_class that's
        # been set by the user
        $spec->{ head_classes }   = \@head_classes;
        $spec->{ body_classes }   = \@body_classes;
        $spec->{ head_class   } ||= join(' ', @head_classes);
        $spec->{ body_class   } ||= join(' ', @body_classes);

        push(@$sane, $spec);
    }

    $self->debug_data( columns => $sane ) if DEBUG;

    return $sane;
}

#sub view {
#    my $self = shift;
#    return $self->{ view }
#       ||= $self->table->hub->view;
#}


sub data {
    my ($self, $options) = self_params(@_);
    my $data = {
        map { $_ => $self->{ $_ } }
        @DATA_ARGS
    };

    if ($options->{ records }) {
        my $recs = $self->records;
        $data->{ results } = [
            map {
                (blessed $_ && $_->can('data'))
                    ? $_->data
                    : $_
            }
            @$recs
        ];

        # shitfucks!  The hash refs in the rows are getting blessed into
        # records and dirtied with table/model refs that JSON can't
        # serialise
        delete $data->{ rows };
    }
    else {
        $data->{ results } = delete $data->{ rows };
    }

    if ($options->{ paging }) {
        $data->{ paging } = $self->buttons;
    }

    return $data;
}


sub dump {
    my $self = shift;
    return join(
        "\n",
        '       sql: ' . $self->{ query },
        '      args: ' . $self->dump_data_inline($self->{ args }),
        '    params: ' . $self->dump_data_inline($self->params_used),
        map { sprintf('%10s: %s', $_, $self->{ $_ }) }
        qw( ident size total limit offset page_no page_size from to more less all )
    );
}


sub debug_dump {
    my $self = shift;
    $self->debug($self->dump);
}


1;
