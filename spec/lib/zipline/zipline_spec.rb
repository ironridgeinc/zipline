require 'spec_helper'
require 'action_controller'

describe Zipline do
  before { Fog.mock! }

  class FakeController < ActionController::Base
    include Zipline
    def download_zip
      files = [
        [StringIO.new("File content goes here"), "one.txt"],
        [StringIO.new("Some other content goes here"), "two.txt"]
      ]
      zipline(files, 'myfiles.zip', auto_rename_duplicate_filenames: false)
    end

    class FailingIO < StringIO
      def read(*)
        raise "Something wonky"
      end
    end

    def download_zip_with_error_during_streaming
      files = [
        [StringIO.new("File content goes here"), "one.txt"],
        [FailingIO.new("This will fail half-way"), "two.txt"]
      ]
      zipline(files, 'myfiles.zip', auto_rename_duplicate_filenames: false)
    end
  end

  it 'passes keyword parameters to ZipTricks::Streamer' do
    fake_rack_env = {
      "HTTP_VERSION" => "HTTP/1.0",
      "REQUEST_METHOD" => "GET",
      "SCRIPT_NAME" => "",
      "PATH_INFO" => "/download",
      "QUERY_STRING" => "",
      "SERVER_NAME" => "host.example",
      "rack.input" => StringIO.new,
    }
    expect(ZipTricks::Streamer).to receive(:new).with(anything, auto_rename_duplicate_filenames: false).and_call_original

    status, headers, body = FakeController.action(:download_zip).call(fake_rack_env)

    expect(headers['Content-Disposition']).to eq("attachment; filename=\"myfiles.zip\"; filename*=UTF-8''myfiles.zip")
  end

  it 'sends the exception raised in the streaming body to the Rails logger' do
    fake_rack_env = {
      "HTTP_VERSION" => "HTTP/1.0",
      "REQUEST_METHOD" => "GET",
      "SCRIPT_NAME" => "",
      "PATH_INFO" => "/download",
      "QUERY_STRING" => "",
      "SERVER_NAME" => "host.example",
      "rack.input" => StringIO.new,
    }
    expect(ZipTricks::Streamer).to receive(:new).with(anything, auto_rename_duplicate_filenames: false).and_call_original
    fake_logger = double()
    expect(Logger).to receive(:new).and_return(fake_logger)
    expect(fake_logger).to receive(:error).with(instance_of(String))

    expect {
      FakeController.action(:download_zip_with_error_during_streaming).call(fake_rack_env)
    }.to raise_error(/Something wonky/)
  end
end
