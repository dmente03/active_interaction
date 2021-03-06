# coding: utf-8
# frozen_string_literal: true

module ActiveInteraction
  # @abstract Include and override {#execute} to implement a custom Runnable
  #   class.
  #
  # @note Must be included after `ActiveModel::Validations`.
  #
  # Runs code and provides the result.
  #
  # @private
  module Runnable
    extend ActiveSupport::Concern
    include ActiveModel::Validations

    included do
      define_callbacks :execute
    end

    # @return [Errors]
    def errors
      @_interaction_errors
    end

    # @abstract
    #
    # @raise [NotImplementedError]
    def execute
      raise NotImplementedError
    end

    # @return [Object] If there are no validation errors.
    # @return [nil] If there are validation errors.
    def result
      @_interaction_result
    end

    # @param result [Object]
    #
    # @return (see #result)
    def result=(result)
      @_interaction_result = result
      @_interaction_valid = errors.empty?
    end

    # @return [Boolean]
    def valid?(*)
      if instance_variable_defined?(:@_interaction_valid)
        return @_interaction_valid
      end

      super
    end

    private

    # @param other [Class] The other interaction.
    # @param (see ClassMethods.run)
    #
    # @return (see #result)
    def compose(other, *args)
      outcome = other.run(*args)

      if outcome.valid?
        outcome.result
      else
        throw :interrupt, outcome.errors
      end
    end

    # @return (see #result=)
    # @return [nil]
    def run
      return unless valid?

      result_or_errors = run_callbacks(:execute) do
        catch(:interrupt) { execute }
      end

      self.result =
        if result_or_errors.is_a?(ActiveInteraction::Errors)
          errors.merge!(result_or_errors)
        else
          result_or_errors
        end
    end

    # @return [Object]
    #
    # @raise [InvalidInteractionError] If there are validation errors.
    def run!
      run

      if valid?
        result
      else
        raise InvalidInteractionError, errors.full_messages.join(', ')
      end
    end

    #
    module ClassMethods
      def new(*)
        super.tap do |instance|
          {
            :@_interaction_errors => Errors.new(instance),
            :@_interaction_result => nil
          }.each do |symbol, obj|
            instance.instance_variable_set(symbol, obj)
          end
        end
      end

      # @param (see Runnable#initialize)
      #
      # @return [Runnable]
      def run(*args)
        new(*args).tap { |instance| instance.send(:run) }
      end

      # @param (see Runnable#initialize)
      #
      # @return (see Runnable#run!)
      #
      # @raise (see Runnable#run!)
      def run!(*args)
        new(*args).send(:run!)
      end
    end
  end
end
