defmodule NewRelic.Error.Logger do
  alias NewRelic.Transaction

  def log(
        %{
          meta: %{error_logger: %{tag: :error_report, type: :crash_report}},
          msg: {:report, %{report: [report | _]}}
        },
        _config
      ) do
    if Transaction.Reporter.tracking?(self()) do
      NewRelic.Error.ErrorHandler.report_transaction_error(report)
    else
      NewRelic.Error.ErrorHandler.report_process_error(report)
    end
  end

  def log(_log, _config), do: :ignore
end
