alias Muster.Storage

ExUnit.start()

ExUnit.after_suite(fn _ ->
    Storage.storage_root()
    |> File.rm_rf!()
end)
