defmodule Muster.Model do
  defmodule MonolithicUploadRequest do
    @enforce_keys [:upload_id, :digest, :blob]
    defstruct ~w[upload_id digest blob]a
  end
  defmodule ChunkedUploadRequest do
    @enforce_keys [:upload_id, :range, :blob]
    defstruct ~w[upload_id range blob]a
  end
  defmodule CompleteUploadRequest do
    @enforce_keys [:upload_id, :digest]
    defstruct ~w[upload_id digest range blob]a
  end
  defmodule ManifestUploadRequest do
    @enforce_keys [:reference, :manifest, :manifest_digest]
    defstruct ~w[reference manifest manifest_digest]a
  end
  defmodule ListTagsRequest do
    defstruct ~w[n last]a

    @spec tuple(%__MODULE__{:last => String.t | nil, :n => integer() | nil}) ::
            {integer() | nil, String.t | nil}
    def tuple(%__MODULE__{n: n, last: last}) do
      {n, last}
    end
  end
end
