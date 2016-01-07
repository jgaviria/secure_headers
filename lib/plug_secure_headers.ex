defmodule PlugSecureHeaders do
  
  use Pipe

  import Plug.Conn, only: [halt: 1, delete_resp_header: 2, update_resp_header: 4]

  @doc "Callback implementation for Plug.init/1"
  def init(options) do
    options
      |> merge?
      |> merge!(options)
      |> validate
  end

  @doc "Callback implementation for Plug.call/2"
  def call(conn, options) do
    case get_config(options) do
      nil -> halt(conn)
      _   -> set_headers(conn, options)
    end
  end
  
  defp validate(options) do
    pipe_matching x, {:ok, x},
      options
      |> PlugSecureHeaders.PlugSecureHeaders.validate
      |> PlugSecureHeaders.ContentSecurityPolicy.validate
      |> PlugSecureHeaders.HttpPublicKeyPins.validate
      |> PlugSecureHeaders.StrictTrasportSecurity.validate
      |> PlugSecureHeaders.XContentTypeOptions.validate
      |> PlugSecureHeaders.XDownloadOptions.validate
      |> PlugSecureHeaders.XFrameOptions.validate
      |> PlugSecureHeaders.XPermittedCrossDomainPolicies.validate
      |> PlugSecureHeaders.XXssProtection.validate
  end
  
  defp set_headers(conn, options) when options |> is_list do
    headers = get_config(options)
    conn 
        |> delete(headers)
        |> set(headers)
  end

  defp set_headers(conn, _) do
    conn
  end

    
  defp set(conn, nil), do: conn
  
  defp set(conn, list) when list |> is_list do
    List.foldl(list, conn, fn({key, value}, conn) -> set(conn, dasherize(key), value) end)
  end
  
  defp set(conn, _key, nil), do: conn
  
  defp set(conn, key, value) when value |> is_bitstring do
    update_resp_header(conn, key, value, fn(_) -> value end)
  end
  
  defp delete(conn, nil), do: conn
  
  defp delete(conn, []), do: conn
  
  defp delete(conn, [h|t]) when h |> is_bitstring do
    conn
    |> delete_resp_header(h)
    |> delete(t)
  end
    
  defp delete(conn, list) when list |> is_list do
    List.foldl(list, conn, fn({key, _}, conn) -> delete(conn, dasherize(key)) end)
  end

  defp delete(conn, key) when key |> is_bitstring, do: delete(conn, [key])
  
  defp dasherize(data) when is_atom(data), do: dasherize(Atom.to_string(data))
  
  defp dasherize(data), do: String.replace(data, "_", "-")

  defp get_config(options), do: get_config(options, [])
  
  defp get_config(options, default_value) do
    case get_in(options, [:plug_secure_headers, :config]) do
      nil -> default_value
      _   -> get_in(options, [:plug_secure_headers, :config])
    end
  end
  
  defp set_config(options, config) when options |> is_list do
    if Keyword.has_key?(options, :plug_secure_headers) do
    	options = Keyword.delete(options[:plug_secure_headers], :config)  ++ [config: config]
    end
    [plug_secure_headers: options]
  end    
    
  defp merge?(options), do: get_in(options, [:plug_secure_headers, :merge])
    
  defp merge_options(options) do
    env_options = Application.get_env(:plug_secure_headers, PlugSecureHeaders, [])    
    merged_options = Keyword.merge(env_options[:plug_secure_headers], options[:plug_secure_headers])
    [plug_secure_headers: merged_options]
  end
    
  defp merge_config(options) do
    env_options = Application.get_env(:plug_secure_headers, PlugSecureHeaders, [])    
    env_config = get_config(env_options)
    config = get_config(options)    
   	merged_config = Keyword.merge(env_config, config)
  	set_config(options, merged_config)#Keyword.delete(options, :config) ++ [config: merged_config]
  end
    
  defp merge!(boolean, options) do
	if(boolean) do
    options =
	  options 
        |> merge_config
        |> merge_options
    end
    options
  end
end  
