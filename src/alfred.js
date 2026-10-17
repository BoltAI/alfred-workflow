// Formats boltai.sh output as Alfred JSON. JavaScript for Automation ships with every macOS, so the
// workflow needs no jq or Python. Usage: osascript -l JavaScript alfred.js <mode> [arguments…]

function scriptFilterError(title, message) {
  return { items: [{ title: title, subtitle: message, valid: false, icon: { path: "icon.png" } }] };
}

function workflowItems(json, source) {
  var workflows = JSON.parse(json);
  if (workflows.length === 0) {
    return scriptFilterError("No AI Workflows", "Create one in BoltAI › Settings › AI Workflows.");
  }
  var on = source === "selection" ? "the selected text" : "the clipboard";
  return {
    items: workflows.map(function (workflow) {
      var kind = workflow.kind === "multi-step" ? "Multi-step: " + (workflow.summary || "") : "AI Workflow";
      if (workflow.enabled === false) kind += " (disabled)";
      return {
        uid: workflow.id,
        title: workflow.name,
        subtitle: kind + " · ↵ run on " + on + " and paste",
        arg: workflow.id,
        // Name only: matching step summaries made "workflow commit" pick a pipe that contains Commit Message.
        match: workflow.name,
        mods: {
          cmd: { arg: workflow.id, subtitle: "Run on " + on + " and copy the result", variables: { action: "copy" } },
          alt: { arg: workflow.id, subtitle: "Edit in BoltAI", variables: { action: "edit" } },
        },
      };
    }),
  };
}

function promptItems(json) {
  var prompts = JSON.parse(json);
  if (prompts.length === 0) {
    return scriptFilterError("No saved prompts", "Save prompts in BoltAI to use them here.");
  }
  return {
    items: prompts.map(function (prompt) {
      return {
        uid: prompt.id,
        title: prompt.name,
        subtitle: (prompt.description ? prompt.description + " · " : "") + "↵ paste the prompt",
        arg: prompt.id,
        match: prompt.name + " " + (prompt.description || ""),
        mods: { cmd: { arg: prompt.id, subtitle: "Copy the prompt", variables: { action: "copy" } } },
      };
    }),
  };
}

function next(arg, variables) {
  return { alfredworkflow: { arg: arg, variables: variables } };
}

function run(argv) {
  var mode = argv[0];
  var output;
  switch (mode) {
    case "workflows":
      output = workflowItems(argv[1], argv[2]);
      break;
    case "prompts":
      output = promptItems(argv[1]);
      break;
    case "error":
      output = scriptFilterError(argv[1], argv[2]);
      break;
    case "result": // text, paste|copy, notice
      output = next(argv[1], { next: argv[2], notice: argv[3] });
      break;
    case "done":
      output = next("", { next: "none" });
      break;
    case "failure": // title, message
      output = next("", { next: "error", error_title: argv[1], error_message: argv[2] });
      break;
    default:
      throw new Error("unknown mode " + mode);
  }
  return JSON.stringify(output);
}
