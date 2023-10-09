package Contentity::Database::Extractor;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Base',
    accessors => 'database',
    utils     => 'strip_hash plural self_params red yellow green split_to_hash',
    constant  => {
        DEV        => 1,
        SERIAL_TYPE => 'bigint(20) unsigned',
        AUTO_INC    => 'auto_increment',
    };


sub init {
    my ($self, $config) = @_;
    $self->{ database } = $config->{ database }
        || return $self->error_msg( missing => 'database' );
    return $self;
}


sub extract_tables {
    my ($self, $params) = self_params(@_);
    my $tables = $self->analyse_tables;
    my $ignore = $params->{ ignore } || '';

    $ignore = split_to_hash($ignore);

    $self->debug_data( tables => $tables ) if DEBUG;

    for my $name (sort keys %$tables) {
        if ($ignore->{ $name }) {
            print yellow " - ignoring $name\n";
            next;
        }
        my $table = $tables->{ $name };
        $self->extract_table($name, $table, $params);
    }
}

sub extract_table {
    my ($self, $name, $table, $params) = @_;
    my $path   = $self->model->table_path($name);
    my $config = $self->workspace->config;
    my $file   = $config->config_file($path);
    if ($file && $file->exists) {
        print red " ! ", $file, " exists\n";
    }
    else {
        $file = $config->write_config_file($path, $table);
        print green " + ", $path, "\n";
    }
    $self->debug_data( $name => $path ) if DEBUG;# or DEV;
}


sub analyse_tables {
    my $self   = shift;
    my $names  = $self->db_table_names;
    my $tables = { };
    for my $name (@$names) {
        my $plural = plural($name);
        $tables->{ $plural } = $self->analyse_table($name);
    }
    $self->debug_data( tables => $tables ) if DEBUG;
    return $tables;
}

sub analyse_table {
    my ($self, $name) = @_;
    my $rows = $self->rows("DESCRIBE `$name`");
    my $table = {
        table   => $name,
        about   => 'This table metadata was generated automatically from the database schema.',
        columns => { },
    };

    for my $row (@$rows) {
        # Default => <undef>,
        # Extra => auto_increment,            # TODO
        # Extra => on update CURRENT_TIMESTAMP,
        # Field => id,
        # Key => PRI/MUL/UNI,
        # Null => NO,
        # Type => bigint(20) unsigned
        my $name    = $row->{ Field };
        my $type    = $row->{ Type  } || '';
        my $extra   = $row->{ Extra } || '';
        my $key     = $row->{ Key   } || '';
        my $null    = $row->{ Null  } || '';
        my $column  = $table->{ columns }->{ $name } ||= { };


        #$column->{ name     } = $name;
        $column->{ default   } = $row->{ default };
        $column->{ mandatory } = $null eq 'NO';

        #$row->{ primary } = $key  eq 'PRI';
        #$column->{ unique   } = $key  eq 'UNI';
        #$column->{ multiple } = $key  eq 'MUL';

        TYPE: {
            if ($type eq SERIAL_TYPE) {
                if ($extra eq AUTO_INC && $key eq 'PRI') {
                    $column->{ type } = 'id';
                    $column->{ automatic } = 1;
                    delete $column->{ mandatory };
                    $table->{ id_field } ||= $name;
                    last TYPE;
                }
                elsif ($name =~ /(\w+?)_id$/) {
                    $column->{ type       } = 'refid';
                    $column->{ references } = plural($1);
                    last TYPE;
                }
                else {
                    $column->{ type       } = 'integer';
                    $column->{ unsigned   } = 1;
                    last TYPE;
                }
            }
            elsif ($type =~ /^enum\((.*?)\)$/) {
                my $opts = [ $type =~ /'(.*?)'/g ];
                $self->debug_data( opts => $opts ) if DEBUG;
                $column->{ options } = $opts;
                $column->{ type    } = 'select';
                last TYPE;
            }
            elsif ($type =~ /^(?:var)?char\((\d+)\)$/) {
                $column->{ type       } = 'text';
                $column->{ max_length } = $1;
                last TYPE;
            }
            elsif ($type =~ /^tinyint\(1\)/) {
                $column->{ type } = 'boolean';
                last TYPE;
            }
            elsif ($type =~ /^(?:big|medium|small|tiny)?int(?:\((\d+)\))?(\s+unsigned)?$/) {
                $column->{ type       } = 'integer';
                $column->{ max_length } = $1 if $1;
                $column->{ unsigned   } = defined $2;
                last TYPE;
            }
            elsif ($type =~ /^(?:decimal|float|double)\((\d+),(\d+)\)$/) {
                $column->{ type       } = 'number';
                $column->{ max_length } = $1;
                $column->{ precision  } = $2;
                last TYPE;
            }
            elsif ($type =~ /^year\(4\)/) {
                $column->{ type } = 'year';
                last TYPE;
            }
            elsif ($type =~ /^(timestamp|text|date|time|datetime)$/) {
                $column->{ type } = $type;
                last TYPE;
            }
            $self->debug_data("can't grok type: $type", $row) if DEBUG or DEV;
        }
        strip_hash($column);
    }
    $self->debug_data( $name => $table ) if DEBUG;
    return $table;
}


sub model {
    shift->database->model;
}

sub workspace {
    shift->database->workspace;
}

sub rows {
    shift->database->rows(@_);
}

sub db_table_names {
    shift->database->db_table_names;
}

sub table_yaml {
    my ($self, $data) = @_;

}


1;

__END__

=head1 NAME

Contentity::Database::Extractor - quick hack to extra table metadata direct from database

=head1 DESCRIPTION

This module examines the scheme of an SQL database and extracts the
metadata required to go into database config files.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2014-2022 Andy Wardley.  All Rights Reserved.

=cut

