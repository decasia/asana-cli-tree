#!/usr/bin/env ruby

require 'asana'
require 'yaml'
require 'paint'
require 'optparse'

include Asana::Resources::ResponseHelper

##### Constants #####

# look for the config file in the user's home folder
CONFIG_PATH = "#{Etc.getpwuid.dir}/.asana-cli-tree.yml"

##### Program logic #####

class LoadTasks
  # Downloads and saves data from the Asana API

  attr_reader :data

  TASK_FIELDS = %w(completed completed_on name parent)

  def initialize(access_token, workspace_id, has_subtask_tag)
    @data = {}
    @complicated_tasks = []

    @workspace_id = workspace_id
    @has_subtask_tag = has_subtask_tag

    @client = Asana::Client.new do |c|
      c.authentication :access_token, access_token
      c.debug_mode
    end
  end

  def load
    load_project_list
    load_tasks_with_subtasks
    load_all_projects
  end

  # initial data load
  def load_project_list
    @projects = @client.projects.find_all workspace: @workspace_id,
      archived: false,
      options: { fields: %w(name layout) }
  end

  def load_tasks_with_subtasks
    # request a list of all tasks that are flagged with the @has_subtask_tag
    @complicated_tasks = @client.tasks.find_by_tag(
      tag: @has_subtask_tag, per_page: 100
    ).map(&:id)
  end

  def load_all_projects
    @projects.each do |project|
      @data[project.to_h] = case project.layout
                       when 'board'
                         load_board_project(project)
                       when 'list'
                         load_list_project(project)
                       end
    end
  end

  def load_subtasks(task_list)
    task_list.reject { |task| !has_subtasks?(task) }
    .map {|task|
      [
        task.id,
        task.subtasks(options: {fields: TASK_FIELDS}, per_page: 50).map(&:to_h)
      ]
    }.to_h
  end

  def load_board_project(project)
    project.sections.map { |section|
      tasks = tasks_for_section(section.id)
      subtasks = load_subtasks(tasks)

      [section.to_h, {tasks: tasks.map(&:to_h), subtasks: subtasks}]
    }.to_h
  end

  def load_list_project(project)
    tasks = @client.tasks.find_all(project: project.id, options: { fields: TASK_FIELDS })
    subtasks = load_subtasks(tasks)

    {tasks: tasks.map(&:to_h), subtasks: subtasks}
  end

  # helpers
  def tasks_for_section(section_id)
    raw_tasks = @client.get("/sections/#{section_id}/tasks?opt_fields=completed,name")
    parsed = Asana::Resources::ResponseHelper.parse(raw_tasks)
    Asana::Collection.new(parsed, type: Asana::Resources::Task, client: @client)
  end

  def has_subtasks?(task)
    @complicated_tasks.include? task.id
  end

  # serialization
  def dump(path)
    File.open(path, 'w') do |out|
      Marshal.dump @data, out
    end
  end
end

class ViewTasks
  # Prints a task tree to the command line

  SEP = "=" * 30

  def initialize(data)
    @data = data
  end

  # Main method for processing projects in a given workspace
  def list_projects
    @data.each do |project, data|
      case project['layout']
      when 'board'
        show_board(project)
      when 'list'
        show_list(project)
      end
    end
  end

  # Display logic for two types of projects: boards and lists
  def show_board(project)
    project_title project['name']

    @data[project].each do |section, section_data|
      section_title section['name']

      tasks = section_data[:tasks]
      tasks.each do |task|
        next if task['completed']

        puts task['name']
        show_subtasks(task['id'], section_data[:subtasks])
      end
    end
  end

  def show_list(project)
    project_title project['name']

    tasks = @data[project][:tasks]

    tasks.each do |task|
      next if task['completed']
      if task['name'] =~ /:$/ # equivalent of a section title
        section_title task['name']
      else
        puts task['name']
        show_subtasks(task['id'], @data[project][:subtasks])
      end
    end
  end

  # utility display methods
  def project_title(title)
    puts Paint["#{SEP} #{title.upcase} #{SEP}", :magenta, :bright]
  end

  def section_title(title)
    puts ''
    puts Paint[title, 'violet']
  end

  def show_subtasks(task_id, subtask_data)
    return unless subtask_data[task_id]

    subtask_data[task_id].each do |subtask|
      next if subtask['completed']
      if subtask['name'] =~ /:$/ # equivalent of a section title
        puts Paint["  #{subtask['name']}", 'royal blue']
      else
        puts "  #{subtask['name']}"
      end
    end
  end
end

##### Imperative script code #####

if __FILE__ == $PROGRAM_NAME
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: view-tasks.rb [options]"
    opts.on("-l", "--load", "Load data") do
      options[:load_data] = true
    end
    opts.on("-v", "--verbose", "Show errors") do |v|
      options[:verbose] = v
    end
  end.parse!

  # Masks constant warnings from FaradayMiddleware::OAuth2.
  # This PR would fix them if merged: https://github.com/Asana/ruby-asana/pull/52
  $stderr = File.new( '/dev/null', 'w' ) if options[:verbose]

  # load config from file
  config = YAML::load_file CONFIG_PATH

  if options[:load_data]
    abort("No saved data available.") unless File.exist? config['dump_path']
    loader = LoadTasks.new(config['access_token'], config['workspace_id'], config['has_subtask_tag'])
    loader.load
    loader.dump(config['dump_path'])
    puts "Data saved to #{config['dump_path']}..."

    data = loader.data
  else
    # load marshalled data
    abort("No saved data available. Invoke with --load-data.") unless File.exist? config['dump_path']
    data = Marshal.load(File.read(config['dump_path']))
  end

  ViewTasks.new(data).list_projects
end
