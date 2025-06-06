<?php

$TAB = "SERVER";

// Main include
include $_SERVER["DOCUMENT_ROOT"] . "/inc/main.php";

// Check user
if ($_SESSION["userContext"] !== "admin" && $user_plain === "$ROOT_USER") {
	header("Location: /list/user");
	exit();
}

// Check POST request
if (!empty($_POST["save"])) {
	if (!empty($_POST["v_config"])) {
		exec("mktemp", $mktemp_output, $return_var);
		$new_conf = $mktemp_output[0];
		$fp = fopen($new_conf, "w");
		$config = str_replace("\r\n", "\n", $_POST["v_config"]);
		if (!str_ends_with($config, "\n")) {
			$config .= "\n";
		}
		fwrite($fp, $config);
		fclose($fp);
		exec(
			CMD . "v-change-sys-service-config " . $new_conf . " Db yes",
			$output,
			$return_var,
		);
		check_return_code($return_var, $output);
		unset($output);
		unlink($new_conf);
	}
}

$v_config_path = "/var/spool/cron/crontabs/eb";
$v_service_name = _("Panel Cronjobs");

// Read config
$v_config = shell_exec(CMD . "v-open-fs-config " . $v_config_path);

// Render page
render_page($user, $TAB, "edit_server_service");

// Flush session messages
unset($_SESSION["error_msg"]);
unset($_SESSION["ok_msg"]);
