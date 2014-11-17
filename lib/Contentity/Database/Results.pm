package Contentity::Database::Results;

use Contentity::Class
    version   => 0.02,
    debug     => 0,
    import    => 'class',
    base      => 'Contentity::Base',
    utils     => 'self_params blessed',
    accessors => 'table ident rows query params args
                  size total limit offset
                  page_no page_size last_page
                  more less all from to',
    mutators  => 'pages_before pages_after',
    alias     => {
        page => 'page_no',
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
    my $self  = shift;
    my $start = $self->start_page;
    my $end   = $self->end_page;
    my $width = $end - $start;
    my $psize = $self->{ page_size };
    my $extra = $self->{ pages_before } + $self->{ pages_after } - $width;
    my $view  = $self->view;
    my @buttons;

    # blanks to ensure we always have the same number of buttons
    foreach (1..$extra) {
        push(@buttons, { blank => 1 });
    }

    # if we're not on the first page then we can go back to the first page
    if ($self->{ less }) {
        my $prev_from = $self->{ from } - $psize;
        my $prev_to   = $self->{ from } - 1;
        push(
            @buttons,
            $view->button(
                first_page  => {
                    to      => $psize,
                    params  => { page_no => 1 },
                }
            ),
            $view->button(
                previous_page  => {
                    from    => $prev_from,
                    to      => $prev_to,
                    params  => { page_no => $self->{ page_no } - 1 },
                }
            ),
        );
    }
    else {
        push(
            @buttons,
            $view->button('no_first_page'),
            $view->button('no_previous_page'),
        );
    }

    foreach my $p ($start..$end) {
        my $page_from = ($p - 1) * $psize + 1;
        my $page_to   = $page_from + $psize - 1;
        my $warm      = $p == $self->{ page_no };
        $page_to = $self->{ total } if $page_to > $self->{ total };

        push(
            @buttons,
            $view->button(
                page_no => {
                    page_no => $p,
                    from    => $page_from,
                    to      => $page_to,
                    text    => $p,
                    warm    => $warm,
                    params  => { page_no => $p },
                },
            ),
        );
    }

    # if we're not on the last page then we can go forward
    if ($self->{ more }) {
        my $next_from = $self->{ from } + $psize;
        my $next_to   = $self->{ to   } + $psize;
        my $last_from = $self->{ last_page } * $psize + 1;
        my $last_to   = $self->{ total };
        $next_to = $self->{ total } if $next_to > $self->{ total };
        push(
            @buttons,
            $view->button(
                next_page  => {
                    from    => $next_from,
                    to      => $next_to,
                    page_no => $self->{ last_page },
                    params  => { page_no => $self->{ page_no } + 1 },
                }
            ),
            $view->button(
                last_page  => {
                    from    => $last_from,
                    to      => $last_to,
                    page_no => $self->{ last_page },
                    params  => { page_no => $self->{ last_page } },
                }
            ),
        );
    }
    else {
        push(
            @buttons,
            $view->button('no_next_page'),
            $view->button('no_last_page'),
        );
    }

    $self->debug("buttons: ", $self->dump_data(\@buttons)) if DEBUG;

    return \@buttons;
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
